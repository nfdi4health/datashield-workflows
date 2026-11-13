# The researcher's pilot (R/scan_methods.R, R/functions/methods/): NCBI's
# answers as recorded XML/JSON, Claude as a stand-in.

pubmed_xml <- '<?xml version="1.0"?>
<PubmedArticleSet>
 <PubmedArticle>
  <MedlineCitation><PMID>111</PMID><Article><ArticleTitle>Diet and diabetes</ArticleTitle>
   <Abstract><AbstractText Label="METHODS">We used Cox regression.</AbstractText>
             <AbstractText Label="RESULTS">HR 1.2.</AbstractText></Abstract></Article></MedlineCitation>
  <PubmedData><ArticleIdList><ArticleId IdType="pubmed">111</ArticleId><ArticleId IdType="pmc">PMC9001</ArticleId></ArticleIdList></PubmedData>
 </PubmedArticle>
 <PubmedArticle>
  <MedlineCitation><PMID>222</PMID><Article><ArticleTitle>No full text</ArticleTitle>
   <Abstract><AbstractText>Plain abstract.</AbstractText></Abstract></Article></MedlineCitation>
  <PubmedData><ArticleIdList><ArticleId IdType="pubmed">222</ArticleId></ArticleIdList></PubmedData>
 </PubmedArticle>
</PubmedArticleSet>'

pmc_xml <- '<?xml version="1.0"?>
<pmc-articleset>
 <article><front><article-meta><article-id pub-id-type="pmc">9001</article-id></article-meta></front>
  <body><sec><title>Introduction</title><p>Background.</p></sec>
   <sec sec-type="methods"><title>Methods</title><p>Cox regression; missing values by multiple imputation.</p></sec></body></article>
 <article><front><article-meta><article-id pub-id-type="pmcid">PMC9002</article-id></article-meta></front>
  <body><sec><title>Statistical analysis</title><p>Restricted cubic splines.</p></sec></body></article>
 <article><front><article-meta><article-id pub-id-type="pmc">9003</article-id></article-meta></front>
  <body><sec><title>Results</title><p>Nothing.</p></sec></body></article>
</pmc-articleset>'

test_that("parse_pubmed_xml() reads ids, title and a labelled abstract", {
  p <- parse_pubmed_xml(pubmed_xml)
  expect_equal(p$pmid, c("111", "222"))
  expect_equal(p$pmcid, c("PMC9001", ""))
  expect_equal(p$abstract[1], "METHODS: We used Cox regression.\nRESULTS: HR 1.2.")
  expect_equal(p$abstract[2], "Plain abstract.")
})

test_that("parse_pmc_methods() finds the methods section by type or title, cut to length", {
  m <- parse_pmc_methods(pmc_xml, max_chars = 20)
  expect_equal(names(m), c("PMC9001", "PMC9002", "PMC9003"))
  expect_equal(m[["PMC9001"]], "Methods Cox regressi")
  expect_match(parse_pmc_methods(pmc_xml)[["PMC9002"]], "Restricted cubic splines")
  expect_equal(m[["PMC9003"]], "")
})

test_that("search_pubmed() asks esearch for the period and returns the ids", {
  seen <- NULL
  mock <- function(req) {
    seen <<- req
    httr2::response(status_code = 200, headers = list("content-type" = "application/json"),
      body = charToRaw('{"esearchresult": {"idlist": ["5", "4"]}}'))
  }
  settings <- read_config_yaml("config/methods-scan.yml")
  ids <- httr2::with_mocked_responses(mock, search_pubmed("diet", "2025/11/13", "2026/11/13", 50, settings))
  expect_equal(ids, c("5", "4"))
  expect_match(seen$url, "esearch.fcgi$")
  form <- seen$body$data
  expect_equal(utils::URLdecode(unclass(form$mindate)), "2025/11/13")
  expect_equal(unclass(form$tool), "datashield-workflows")
  expect_null(form$email)
})

test_that("ask_claude_for_method_sources() keeps the methods of the given papers, normalised", {
  papers <- data.frame(pmid = c("111", "333"), abstract = c("a", "b"), methods = c("m", "n"))
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    expect_match(prompt, '<paper id="111">', fixed = TRUE)
    list(papers = list(
      list(id = "111", methods = list(
        list(name = "Cox Regression.", role = "main", in_abstract = TRUE, in_methods_section = TRUE),
        list(name = "multiple  imputation", role = "secondary", in_abstract = FALSE, in_methods_section = TRUE))),
      list(id = "999", methods = list(list(name = "invented", role = "main", in_abstract = TRUE, in_methods_section = TRUE)))))
  })
  claude <- list(prompt = "{{PAPERS}}", config = list())
  found <- ask_claude_for_method_sources(claude, papers, list(pilot = list(batch = 5)))
  expect_equal(found$name, c("cox regression", "multiple imputation"))
  expect_false("invented" %in% found$name)
})

test_that("a failed batch is left out and the others go on", {
  papers <- data.frame(pmid = c("1", "2"), abstract = c("a", "b"), methods = c("m", "n"))
  calls <- 0
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    calls <<- calls + 1
    if (calls == 1) stop("usage limit")
    list(papers = list(list(id = "2", methods = list(list(name = "t-test", role = "secondary", in_abstract = FALSE, in_methods_section = TRUE)))))
  })
  expect_message(found <- ask_claude_for_method_sources(list(prompt = "{{PAPERS}}", config = list()), papers, list(pilot = list(batch = 1))),
    "left out")
  expect_equal(found$id, "2")
})

test_that("the pilot report gives the shares by role and the methods only in the methods section", {
  found <- data.frame(
    id = c("1", "1", "2", "2", "3"),
    name = c("cox regression", "multiple imputation", "cox regression", "multiple imputation", "splines"),
    role = c("main", "secondary", "main", "secondary", "secondary"),
    in_abstract = c(TRUE, FALSE, TRUE, FALSE, TRUE),
    in_methods_section = c(TRUE, TRUE, TRUE, TRUE, FALSE)
  )
  s <- summarise_method_sources(found, 3)
  expect_equal(s$methods_in_sections, 4)
  expect_equal(s$share_main, 1)
  expect_equal(s$share_secondary, 0)
  expect_equal(s$abstract_only, 1)
  expect_equal(s$only_in_section$method, "multiple imputation")
  report <- paste(format_pilot_report(s, "cohort-nutrition", "2025-11-13 to 2026-11-13"), collapse = "\n")
  expect_match(report, "| main analyses | 100% |", fixed = TRUE)
  expect_match(report, "| multiple imputation | 2 |", fixed = TRUE)
})

test_that("scan_methods.R runs the pilot end to end and writes the report", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("queries:", "  - name: cohort-nutrition", "    pubmed: 'diet[tiab]'"), file.path(dir, "config", "methods-scan.yml"))
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared)
  for (part in c("R", "config", "prompts")) file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  answer <- function(type, text) httr2::response(status_code = 200, headers = list("content-type" = type), body = charToRaw(text))
  terms <- character(0)
  mock <- function(req) {
    form <- lapply(req$body$data, function(x) utils::URLdecode(unclass(x)))
    if (grepl("esearch", req$url)) {
      terms <<- c(terms, form$term)
      return(answer("application/json", '{"esearchresult": {"idlist": ["111", "222"]}}'))
    }
    if (identical(form$db, "pubmed")) return(answer("text/xml", pubmed_xml))
    answer("text/xml", pmc_xml)
  }
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    list(papers = list(list(id = "111", methods = list(
      list(name = "Cox regression", role = "main", in_abstract = TRUE, in_methods_section = TRUE),
      list(name = "multiple imputation", role = "secondary", in_abstract = FALSE, in_methods_section = TRUE)))))
  })
  before <- ls(globalenv(), all.names = TRUE)
  on.exit(rm(list = setdiff(ls(globalenv(), all.names = TRUE), before), envir = globalenv()), add = TRUE)
  withr::with_dir(dir, withr::with_envvar(c(SCAN_MODE = "pilot", SCAN_QUERY = ""), httr2::with_mocked_responses(mock, {
    # the entry script sources the functions again: keep the stand-in
    stand_in <- get("call_claude_tool", globalenv())
    trace_source <- function(file, ...) { base::source(file, ...); assign("call_claude_tool", stand_in, globalenv()) }
    sys.source(file.path(".shared-workflows", "R", "scan_methods.R"), envir = list2env(list(source = trace_source), parent = globalenv()))
  })))
  expect_match(terms, '(diet[tiab]) AND "pubmed pmc open access"[filter]', fixed = TRUE)
  report <- readLines(file.path(dir, "methods_pilot_report.md"))
  expect_true(any(grepl("Query **cohort-nutrition**", report, fixed = TRUE)))
  expect_true(any(grepl("**1** papers compared", report, fixed = TRUE)))
  expect_true(any(grepl("| multiple imputation | 1 |", report, fixed = TRUE)))
  expect_true(file.exists(file.path(dir, "methods_pilot.json")))
})
