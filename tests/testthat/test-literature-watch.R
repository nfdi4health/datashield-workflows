# The literature watch (R/watch_literature.R, R/functions/literature/): NCBI's
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
  settings <- read_config_yaml("config/literature-watch.yml")
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
    if (calls == 1) stop("Internal server error")
    list(papers = list(list(id = "2", methods = list(list(name = "t-test", role = "secondary", in_abstract = FALSE, in_methods_section = TRUE)))))
  })
  expect_message(found <- ask_claude_for_method_sources(list(prompt = "{{PAPERS}}", config = list()), papers, list(pilot = list(batch = 1))),
    "left out")
  expect_equal(found$id, "2")
  expect_equal(attr(found, "asked"), 1)
  expect_false(attr(found, "stopped"))
})

test_that("the summary gives the shares by role and the methods only in the methods section", {
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
})

watch_entry <- function(pmids, method = "cox regression", in_abstract = TRUE) {
  list(pubmed = "diet[tiab]", from = "2025-11-16", to = "2026-11-16", found = length(pmids),
    with_methods_section = length(pmids), compared = length(pmids), stopped = FALSE,
    papers = lapply(pmids, function(id) list(pmid = id, pmcid = paste0("PMC", id), title = "T",
      methods = list(list(name = method, role = "secondary", in_abstract = in_abstract, in_methods_section = TRUE)))))
}

test_that("a re-run of one query replaces its entry and keeps the others", {
  old <- merge_watch_data(NULL, "2026-11", "pilot", list(a = watch_entry("1"), b = watch_entry("2")))
  new <- merge_watch_data(old, "2026-11", "pilot", list(b = watch_entry(c("3", "4"))))
  expect_equal(names(new$queries), c("a", "b"))
  expect_equal(new$queries$a$compared, 1)
  expect_equal(new$queries$b$compared, 2)
})

test_that("the report has all queries together, a section per query, and counts a paper once", {
  data <- merge_watch_data(NULL, "2026-11", "pilot",
    list(a = watch_entry(c("1", "2"), "splines", FALSE), b = watch_entry(c("2", "3"))))
  report <- paste(format_watch_report(data, missing = "c"), collapse = "\n")
  expect_match(report, "# Literature watch 2026-11", fixed = TRUE)
  expect_match(report, "## All queries", fixed = TRUE)
  expect_match(report, "Papers compared, each counted once: **3**.", fixed = TRUE)
  expect_match(report, "## a", fixed = TRUE)
  expect_match(report, "| splines | 2 |", fixed = TRUE)
  expect_match(report, "_Not run this month: c._", fixed = TRUE)
  one <- paste(format_watch_report(merge_watch_data(NULL, "2026-11", "pilot", list(a = watch_entry("1")))), collapse = "\n")
  expect_false(grepl("## All queries", one, fixed = TRUE))
})

test_that("watch_literature.R runs every query, keeps the month's other results and writes data and report", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("queries:", "  - name: cohort-nutrition", "    pubmed: 'diet[tiab]'", "  - name: cohort-diabetes", "    pubmed: 'diabetes[tiab]'"),
    file.path(dir, "config", "literature-watch.yml"))
  dir.create(file.path(dir, "literature-watch", "data"), recursive = TRUE)
  yaml::write_yaml(merge_watch_data(NULL, "2026-11", "pilot", list(older = watch_entry("9"))), file.path(dir, "literature-watch", "data", "2026-11.yml"))
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
  withr::with_dir(dir, withr::with_envvar(c(WATCH_MODE = "pilot", WATCH_QUERY = "", WATCH_MONTH = "2026-11"), httr2::with_mocked_responses(mock, {
    # the entry script sources the functions again: keep the stand-in
    stand_in <- get("call_claude_tool", globalenv())
    trace_source <- function(file, ...) { base::source(file, ...); assign("call_claude_tool", stand_in, globalenv()) }
    sys.source(file.path(".shared-workflows", "R", "watch_literature.R"), envir = list2env(list(source = trace_source), parent = globalenv()))
  })))
  expect_match(terms[1], '(diet[tiab]) AND "pubmed pmc open access"[filter]', fixed = TRUE)
  expect_match(terms[2], '(diabetes[tiab])', fixed = TRUE)
  data <- yaml::read_yaml(file.path(dir, "literature-watch", "data", "2026-11.yml"))
  expect_equal(names(data$queries), c("older", "cohort-nutrition", "cohort-diabetes"))
  expect_equal(data$queries[["cohort-nutrition"]]$papers[[1]]$pmid, "111")
  expect_null(data$queries[["cohort-nutrition"]]$papers[[1]]$abstract)
  report <- readLines(file.path(dir, "literature-watch", "reports", "2026-11.md"))
  expect_true(any(grepl("## cohort-nutrition", report, fixed = TRUE)))
  expect_true(any(grepl("## older", report, fixed = TRUE)))
  expect_true(any(grepl("| multiple imputation | 1 |", report, fixed = TRUE)))
  expect_equal(readLines(file.path(dir, "watch_files.txt")),
    c("literature-watch/data/2026-11.yml", "literature-watch/reports/2026-11.md"))
})

test_that("at the usage limit the calls stop, and the result says how far they got", {
  papers <- data.frame(pmid = c("1", "2", "3"), abstract = c("a", "b", "c"), methods = c("m", "n", "o"))
  calls <- 0
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    calls <<- calls + 1
    if (calls == 2) stop("Claude Code ended without an answer (error): 5-hour limit reached - resets 3pm")
    list(papers = list(list(id = "1", methods = list(list(name = "t-test", role = "secondary", in_abstract = TRUE, in_methods_section = TRUE)))))
  })
  expect_message(found <- ask_claude_for_method_sources(list(prompt = "{{PAPERS}}", config = list()), papers, list(pilot = list(batch = 1))),
    "usage limit was reached after 1 papers")
  expect_equal(calls, 2)
  expect_equal(attr(found, "asked"), 1)
  expect_true(attr(found, "stopped"))
  expect_true(is_usage_limit("You've hit your usage limit"))
  expect_false(is_usage_limit("Internal server error"))
})
