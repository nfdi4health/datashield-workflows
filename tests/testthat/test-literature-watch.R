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

test_that("parse_pmc_methods() puts the statistics subsection first, so the cut keeps it", {
  xml <- '<?xml version="1.0"?>
<pmc-articleset><article><front><article-meta><article-id pub-id-type="pmc">7</article-id></article-meta></front>
 <body><sec sec-type="methods"><title>Methods</title>
  <sec><title>Participants</title><p>A long description of the cohort.</p></sec>
  <sec><title>Statistical analysis</title><p>Fine-Gray regression.</p></sec></sec></body></article></pmc-articleset>'
  m <- parse_pmc_methods(xml, max_chars = 60)
  expect_match(m[["PMC7"]], "^Statistical analysis Fine-Gray regression")
})


test_that("parse_pubmed_xml() also reads journal and DOI", {
  xml <- '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle><MedlineCitation><PMID>5</PMID><Article>
   <Journal><ISOAbbreviation>Eur J Epidemiol</ISOAbbreviation></Journal><ArticleTitle>T</ArticleTitle></Article></MedlineCitation>
   <PubmedData><ArticleIdList><ArticleId IdType="doi">10.1/x</ArticleId></ArticleIdList></PubmedData></PubmedArticle></PubmedArticleSet>'
  p <- parse_pubmed_xml(xml)
  expect_equal(p$journal, "Eur J Epidemiol")
  expect_equal(p$doi, "10.1/x")
})

test_that("the months run newest first from the lag back over the years", {
  m <- watch_months("2026-11-16", lag_months = 2, years_back = 5)
  expect_equal(length(m), 60)
  expect_equal(m[1], "2026-09")
  expect_equal(m[60], "2021-10")
  expect_equal(watch_months("2026-01-31", 2, 1)[1], "2025-11")
  expect_equal(month_range("2024-02"), c("2024/02/01", "2024/02/29"))
})

test_that("a field's search wraps its own part between design and filters", {
  settings <- list(search = list(design = "D", filters = "F NOT (R)"))
  expect_equal(field_search(list(pubmed = "a OR b"), settings), "D AND (a OR b) AND F NOT (R)")
})

test_that("search_month_ids() asks for the month's publication dates, page by page", {
  seen <- list()
  mock <- function(req) {
    form <- lapply(req$body$data, function(x) utils::URLdecode(unclass(x)))
    seen[[length(seen) + 1]] <<- form
    ids <- if (form$retstart == "0") '["1","2"]' else '["3"]'
    httr2::response(status_code = 200, headers = list("content-type" = "application/json"),
      body = charToRaw(sprintf('{"esearchresult": {"count": "3", "idlist": %s}}', ids)))
  }
  settings <- read_config_yaml("config/literature-watch.yml")
  found <- httr2::with_mocked_responses(mock, search_month_ids("diet", "2024-02", settings, page = 2))
  expect_equal(found$ids, c("1", "2", "3"))
  expect_equal(found$count, 3L)
  expect_equal(seen[[1]]$mindate, "2024/02/01")
  expect_equal(seen[[1]]$maxdate, "2024/02/29")
  expect_equal(seen[[1]]$datetype, "pdat")
  expect_equal(seen[[2]]$retstart, "2")
  expect_equal(seen[[1]]$tool, "datashield-workflows")
  expect_null(seen[[1]]$email)
})

test_that("a field's order is stable, and a late paper takes its place without moving the others' keys", {
  k <- sample_keys("cardiovascular", c("10", "20", "30"))
  expect_equal(k, sample_keys("cardiovascular", c("10", "20", "30")))
  expect_false(identical(k, sample_keys("metabolic", c("10", "20", "30"))))
  expect_equal(sample_keys("cardiovascular", c("10", "20", "30", "40"))[1:3], k)
})

test_that("the lookup tables add new versions and retire old ones, never deleting a row", {
  path <- file.path(withr::local_tempdir(), "queries.csv")
  update_lookup_table(path, data.frame(fingerprint = "a1", group = "cvd", search = "x"), "2026-11-20")
  update_lookup_table(path, data.frame(fingerprint = "a1", group = "cvd", search = "x"), "2026-11-21")
  t <- update_lookup_table(path, data.frame(fingerprint = "b2", group = "cvd", search = "y"), "2027-01-01")
  expect_equal(t$fingerprint, c("a1", "b2"))
  expect_equal(t$status, c("retired", "active"))
  expect_equal(t$used_until[1], "2027-01-01")
  expect_equal(t$used_from[2], "2027-01-01")
})

# A small world for run_watch_chunk(): one month with papers, the other
# months empty; every paper usable except "bad".
watch_world <- function(ids_by_field, target = 2, years_back = 1, claude_fails_at = Inf) {
  settings <- list(
    search = list(design = "D", filters = "F"),
    sampling = list(target_per_month = target, years_back = years_back, lag_months = 2, recheck_months = 1),
    reading = list(batch = 5)
  )
  calls <- 0
  searched <- character(0)
  local_global_mock(
    search_month_ids = function(search, month, settings) {
      searched <<- c(searched, paste(month, search))
      if (month != "2026-09") return(list(ids = character(0), count = 0L))
      field <- if (grepl("cvd", search)) "cvd" else "met"
      list(ids = ids_by_field[[field]], count = length(ids_by_field[[field]]))
    },
    fetch_paper_texts = function(pmids, settings) {
      data.frame(pmid = pmids, pmcid = paste0("PMC", pmids), doi = "", journal = "J", title = paste("Paper", pmids),
        abstract = "a", methods = ifelse(pmids == "bad", "", "m"))
    },
    call_claude_tool = function(claude, tool, prompt) {
      calls <<- calls + 1
      if (calls >= claude_fails_at) stop("5-hour limit reached - resets 3pm")
      ids <- regmatches(prompt, gregexpr('(?<=<paper id=")[^"]+', prompt, perl = TRUE))[[1]]
      list(papers = lapply(ids, function(id) list(id = id, methods = list(
        list(name = "Cox regression", variant = "", role = "main", in_abstract = TRUE, in_methods_section = TRUE)))))
    },
    env = parent.frame()
  )
  list(settings = settings, dir = withr::local_tempdir(.local_envir = parent.frame()),
    fields = list(list(name = "cvd", pubmed = "cvd"), list(name = "met", pubmed = "met")),
    claude = list(prompt = "{{PAPERS}}", config = list()),
    calls = function() calls, searched = function() searched)
}

test_that("a run reads each field's sample once, a shared paper once, and records which fields found it", {
  ids <- list(cvd = c("1", "2", "3", "4"), met = c("2", "3", "5", "6"))
  w <- watch_world(ids, target = 4)
  res <- run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  expect_equal(res$stopped, "done")
  expect_equal(res$read, 6)
  reg <- read_register(w$dir)
  expect_setequal(names(reg$papers), c("1", "2", "3", "4", "5", "6"))
  expect_setequal(names(reg$papers[["2"]]$found_by), c("cvd", "met"))
  expect_equal(reg$papers[["1"]]$methods[[1]]$name, "cox regression")
  expect_equal(reg$papers[["1"]]$read$reader, "r1")
  expect_null(reg$papers[["1"]]$abstract)
  expect_true(file.exists(file.path(w$dir, "papers", "2026", "2026-09.jsonl")))
  state <- read_months_state(w$dir)
  row <- state[state$field == "met" & state$month == "2026-09", ]
  expect_equal(row$sample_read, 4L)
  expect_equal(row$total, 4L)
})

test_that("the budget stops a run, and the next run carries on without reading anything twice", {
  ids <- list(cvd = as.character(1:8), met = character(0))
  w <- watch_world(ids, target = 8)
  first <- run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 5, reader = "r1")
  expect_equal(first$stopped, "budget")
  expect_equal(first$read, 5)
  calls_before <- w$calls()
  second <- run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  expect_equal(second$read, 3)
  expect_equal(length(read_register(w$dir)$papers), 8)
})

test_that("raising the target reads only the next papers in the order", {
  ids <- list(cvd = as.character(1:10), met = character(0))
  w <- watch_world(ids, target = 3)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  first <- names(read_register(w$dir)$papers)
  w$settings$sampling$target_per_month <- 6
  res <- run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-17"), budget = 100, reader = "r1")
  expect_equal(res$read, 3)
  reg <- read_register(w$dir)
  expect_true(all(first %in% names(reg$papers)))
  keys <- sample_keys("cvd", ids$cvd)
  expect_setequal(names(reg$papers), ids$cvd[order(keys)][1:6])
})

test_that("a late paper joins the sample where its key puts it, and the last one drops out", {
  ids <- list(cvd = as.character(1:6), met = character(0))
  w <- watch_world(ids, target = 3)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  # a new paper whose key comes first in the order
  candidates <- as.character(100:200)
  late <- candidates[order(sample_keys("cvd", candidates))[1]]
  w2 <- watch_world(list(cvd = c(ids$cvd, late), met = character(0)), target = 3)
  w2$dir <- w$dir
  res <- run_watch_chunk(w2$settings, w2$fields, w2$dir, w2$claude, as.Date("2026-11-17"), budget = 100, reader = "r1")
  expect_equal(res$read, 1)
  state <- read_months_state(w$dir)
  row <- state[state$field == "cvd" & state$month == "2026-09", ]
  all_keys <- sort(sample_keys("cvd", c(ids$cvd, late)))
  expect_equal(row$threshold, all_keys[3])
  expect_equal(row$total, 7L)
})

test_that("a paper without a methods section is kept as read but not usable, and not asked again", {
  w <- watch_world(list(cvd = c("1", "bad"), met = character(0)), target = 2)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  reg <- read_register(w$dir)
  expect_false(reg$papers[["bad"]]$usable)
  expect_true(reg$papers[["1"]]$usable)
  calls <- w$calls()
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-17"), budget = 100, reader = "r1")
  expect_equal(w$calls(), calls)
})

test_that("at the usage limit a run stops and keeps what it has read", {
  w <- watch_world(list(cvd = as.character(1:10), met = character(0)), target = 10, claude_fails_at = 2)
  res <- run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  expect_equal(res$stopped, "limit")
  expect_equal(res$read, 5)
  expect_equal(length(read_register(w$dir)$papers), 5)
})

test_that("a complete month is searched again only while it is recent and not yet today", {
  w <- watch_world(list(cvd = c("1"), met = c("2")), target = 1, years_back = 1)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  n <- length(w$searched())
  expect_equal(n, 24)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  expect_equal(length(w$searched()), n)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-17"), budget = 100, reader = "r1")
  expect_equal(length(w$searched()) - n, 2)
})

test_that("the progress counts complete months and read papers per field", {
  w <- watch_world(list(cvd = as.character(1:4), met = character(0)), target = 2)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 1, reader = "r1")
  months <- watch_months("2026-11-16", 2, 1)
  queries <- list(cvd = hash_keys("D AND (cvd) AND F"), met = hash_keys("D AND (met) AND F"))
  p <- watch_progress(read_months_state(w$dir), w$fields, months, 2, queries)
  expect_equal(p$months_complete, c(0, 0))
  expect_equal(p$papers_read[1], 1)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  p <- watch_progress(read_months_state(w$dir), w$fields, months, 2, queries)
  expect_equal(p$months_complete, c(12, 12))
  expect_equal(p$papers_read[1], 2)
})

test_that("only papers within a field's sample count for it", {
  ids <- list(cvd = as.character(1:6), met = as.character(1:6))
  w <- watch_world(ids, target = 6)
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-16"), budget = 100, reader = "r1")
  w$settings$sampling$target_per_month <- 2
  run_watch_chunk(w$settings, w$fields, w$dir, w$claude, as.Date("2026-11-17"), budget = 100, reader = "r1")
  reg <- read_register(w$dir)
  state <- read_months_state(w$dir)
  months <- watch_months("2026-11-17", 2, 1)
  q <- hash_keys("D AND (met) AND F")
  counted <- field_papers(reg, state, "met", q, months)
  expect_equal(length(counted), 2)
  expect_setequal(names(counted), ids$met[order(sample_keys("met", ids$met))][1:2])
  expect_equal(length(field_papers(reg, state, "met", "other-version", months)), 0)
})

test_that("method_trend() tells rising, falling and steady apart", {
  years <- 2021:2025
  expect_equal(method_trend(years, c(10, 20, 30, 40, 50), rep(300, 5)), "rising")
  expect_equal(method_trend(years, c(50, 40, 30, 20, 10), rep(300, 5)), "falling")
  expect_equal(method_trend(years, c(30, 31, 29, 30, 30), rep(300, 5)), "steady")
  expect_equal(method_trend(2024:2025, c(1, 2), c(10, 10)), "–")
})

watch_paper <- function(pmid, month, methods, usable = TRUE) {
  list(pmid = pmid, month = month, usable = usable,
    methods = lapply(methods, function(m) list(name = m[1], variant = if (length(m) > 1) m[2] else NULL)))
}

test_that("method_table() gives shares per year over usable papers, each paper once per method", {
  papers <- list(
    a = watch_paper("a", "2025-01", list(c("cox regression"), c("cox regression", "stratified"))),
    b = watch_paper("b", "2025-02", list(c("t-test"))),
    c = watch_paper("c", "2024-05", list(c("cox regression"))),
    d = watch_paper("d", "2024-06", list(), usable = FALSE))
  t <- method_table(papers, c("2024", "2025"), recent = c("2025-01", "2025-02"))
  expect_equal(t$method[1], "cox regression")
  expect_equal(t$share[1], 0.5)
  expect_equal(t[["2024"]][1], 1)
  expect_equal(unname(attr(t, "papers_year")), c(1, 2))
  v <- variant_table(papers, min_papers = 1)
  expect_equal(v$variant, "stratified")
  expect_null(variant_table(papers, min_papers = 2))
})

test_that("watch_literature.R and report_literature.R read a stretch, write the data and build the report", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("fields:", "  - name: nutrition", "    pubmed: 'diet[majr]'", "  - name: metabolic", "    pubmed: 'obesity[majr]'",
    "sampling:", "  target_per_month: 2", "  years_back: 1"), file.path(dir, "config", "literature-watch.yml"))
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared)
  for (part in c("R", "config", "prompts")) file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  answer <- function(type, text) httr2::response(status_code = 200, headers = list("content-type" = type), body = charToRaw(text))
  terms <- character(0)
  mock <- function(req) {
    form <- lapply(req$body$data, function(x) utils::URLdecode(unclass(x)))
    if (grepl("esearch", req$url)) {
      terms <<- c(terms, form$term)
      in_month <- form$mindate == "2026/09/01"
      ids <- if (in_month) '["111", "222"]' else "[]"
      return(answer("application/json", sprintf('{"esearchresult": {"count": "%d", "idlist": %s}}', if (in_month) 2L else 0L, ids)))
    }
    if (identical(form$db, "pubmed")) return(answer("text/xml", pubmed_xml))
    answer("text/xml", pmc_xml)
  }
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    list(papers = list(list(id = "111", methods = list(
      list(name = "Cox regression", variant = "Time-varying covariates", role = "main", in_abstract = TRUE, in_methods_section = TRUE)))))
  })
  before <- ls(globalenv(), all.names = TRUE)
  on.exit(rm(list = setdiff(ls(globalenv(), all.names = TRUE), before), envir = globalenv()), add = TRUE)
  run_script <- function(name) {
    stand_in <- get("call_claude_tool", globalenv())
    trace_source <- function(file, ...) { base::source(file, ...); assign("call_claude_tool", stand_in, globalenv()) }
    sys.source(file.path(".shared-workflows", "R", name), envir = list2env(list(source = trace_source), parent = globalenv()))
  }
  withr::with_dir(dir, withr::with_envvar(c(WATCH_TODAY = "2026-11-16", WATCH_DATA_DIR = "watch-data", WATCH_FIELD = "",
    WATCH_MAX_PAPERS = "", WATCH_CHUNK = "250"), httr2::with_mocked_responses(mock, {
      run_script("watch_literature.R")
      run_script("report_literature.R")
    })))
  expect_match(terms[1], '"Epidemiologic Studies"[MeSH Terms] AND (diet[majr]) AND "pubmed pmc open access"[filter] NOT (review[pt]', fixed = TRUE)
  data <- file.path(dir, "watch-data", "literature-watch", "data")
  status <- jsonlite::fromJSON(file.path(dir, "watch_status.json"))
  expect_equal(status$stopped, "done")
  expect_equal(status$read, 2)
  expect_true(status$complete)
  lines <- readLines(file.path(data, "papers", "2026", "2026-09.jsonl"))
  expect_equal(length(lines), 2)
  rec <- jsonlite::fromJSON(lines[1], simplifyVector = FALSE)
  expect_equal(rec$pmid, "111")
  expect_setequal(names(rec$found_by), c("nutrition", "metabolic"))
  expect_null(rec$abstract)
  expect_equal(rec$methods[[1]]$variant, "time-varying covariates")
  expect_false(jsonlite::fromJSON(lines[2], simplifyVector = FALSE)$usable)
  queries <- utils::read.csv(file.path(data, "queries.csv"))
  expect_equal(queries$group, c("nutrition", "metabolic"))
  expect_equal(nrow(utils::read.csv(file.path(data, "readers.csv"))), 1)
  report <- readLines(file.path(dir, "literature-watch", "reports", "overview.md"))
  expect_true(any(grepl("| nutrition | 12 / 12 | 2 / 2 |", report, fixed = TRUE)))
  expect_true(any(grepl("| Method | Share, last year |", report, fixed = TRUE)))
  expect_true(any(grepl("| cox regression | 100% | 1 |", report, fixed = TRUE)))
  expect_true(any(grepl("| cox regression | time-varying covariates | 1 |", report, fixed = TRUE)) == FALSE)
  expect_match(readLines(file.path(dir, "report_title.txt")), "round complete")
  expect_equal(readLines(file.path(dir, "watch_files.txt")), "literature-watch/reports/overview.md")
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
  found <- ask_claude_for_method_sources(claude, papers, list(reading = list(batch = 5)))
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
  expect_message(found <- ask_claude_for_method_sources(list(prompt = "{{PAPERS}}", config = list()), papers, list(reading = list(batch = 1))),
    "left out")
  expect_equal(found$id, "2")
  expect_equal(attr(found, "asked"), 1)
  expect_false(attr(found, "stopped"))
})

test_that("at the usage limit the calls stop, and the result says how far they got", {
  papers <- data.frame(pmid = c("1", "2", "3"), abstract = c("a", "b", "c"), methods = c("m", "n", "o"))
  calls <- 0
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    calls <<- calls + 1
    if (calls == 2) stop("Claude Code ended without an answer (error): 5-hour limit reached - resets 3pm")
    list(papers = list(list(id = "1", methods = list(list(name = "t-test", role = "secondary", in_abstract = TRUE, in_methods_section = TRUE)))))
  })
  expect_message(found <- ask_claude_for_method_sources(list(prompt = "{{PAPERS}}", config = list()), papers, list(reading = list(batch = 1))),
    "usage limit was reached after 1 papers")
  expect_equal(calls, 2)
  expect_equal(attr(found, "asked"), 1)
  expect_true(attr(found, "stopped"))
  expect_true(is_usage_limit("You've hit your usage limit"))
  expect_false(is_usage_limit("Internal server error"))
})
