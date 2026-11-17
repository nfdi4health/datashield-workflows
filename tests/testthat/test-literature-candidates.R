# The literature watch's candidates (R/candidates_literature.R): ranking,
# decisions, the pull request's text, Claude's research as a stand-in.

cand_paper <- function(pmid, month, methods, fields = "cancer") {
  list(pmid = pmid, month = month, usable = TRUE, title = paste("Paper", pmid), journal = "J",
    found_by = stats::setNames(lapply(fields, function(f) list(key = "a", query = "q")), fields),
    methods = lapply(methods, function(m) list(name = m[1], variant = if (length(m) > 1) m[2] else NULL)))
}
cand_vocab <- function() {
  v <- list(methods = list(), names = list(), variant_names = list())
  v$methods[["fine-gray"]] <- list(name = "Fine-Gray regression", description = "Competing risks.",
    exists = list(verdict = "none", `function` = "", note = "Nothing pooled."))
  v$methods[["cox-regression"]] <- list(name = "Cox regression",
    exists = list(verdict = "yes", `function` = "dsSurvivalClient::ds.coxph"),
    variants = list(`time-varying` = list(name = "time-varying covariates",
      exists = list(verdict = "partial", `function` = "dsSurvivalClient::ds.coxph", note = "No time-varying terms."))))
  v$methods[["mice"]] <- list(name = "Multiple imputation", exists = list(verdict = "development", `function` = "dsX::ds.mice"))
  v$names[["fine-gray"]] <- list(method = "fine-gray")
  v$names[["cox"]] <- list(method = "cox-regression")
  v$names[["mi"]] <- list(method = "mice")
  v$variant_names[["cox-regression"]][["tvc"]] <- list(variant = "time-varying")
  v
}
cand_register <- function() {
  reg <- new.env()
  ps <- c(lapply(1:6, function(i) cand_paper(as.character(i), "2026-09", list("fine-gray", "mi"))),
    lapply(7:12, function(i) cand_paper(as.character(i), "2026-08", list(c("cox", "tvc")), "cardiovascular")),
    lapply(13:14, function(i) cand_paper(as.character(i), "2026-08", list("cox"))))
  reg$papers <- stats::setNames(ps, vapply(ps, function(p) p$pmid, ""))
  reg
}
cand_settings <- list(candidates = list(min_papers = 5, resuggest_factor = 2, examples = 2, max = 10))

test_that("candidate_units() takes missing and partial methods and variants, not development ones", {
  u <- candidate_units(cand_vocab())
  expect_setequal(u$key, c("fine-gray", "cox-regression/time-varying"))
})

test_that("rank_candidates() counts papers, orders by share and applies tracked issues and decisions", {
  months <- c("2026-09", "2026-08")
  r <- rank_candidates(cand_register(), cand_vocab(), cand_settings, list(), list(), months, months)
  expect_equal(r$key, c("cox-regression/time-varying", "fine-gray"))
  expect_equal(r$papers, c(6, 6))
  expect_equal(r$status, c("new", "new"))
  expect_equal(r$fields[r$key == "fine-gray"], "cancer")
  expect_length(jsonlite::fromJSON(r$examples[1], simplifyVector = FALSE), 2)
  tracked <- rank_candidates(cand_register(), cand_vocab(), cand_settings, list(), list(`fine-gray` = 7), months, months)
  expect_equal(tracked$status[tracked$key == "fine-gray"], "tracked")
  d <- list(`fine-gray` = list(decision = "dont-suggest", papers = 4), `cox-regression/time-varying` = list(decision = "not-now"))
  decided <- rank_candidates(cand_register(), cand_vocab(), cand_settings, d, list(), months, months)
  expect_equal(decided$status[decided$key == "fine-gray"], "skipped")
  expect_equal(decided$status[decided$key == "cox-regression/time-varying"], "deferred")
  d$`fine-gray`$papers <- 3
  again <- rank_candidates(cand_register(), cand_vocab(), cand_settings, d, list(), months, months)
  expect_equal(again$status[again$key == "fine-gray"], "new")
  few <- rank_candidates(cand_register(), cand_vocab(), list(candidates = list(min_papers = 7)), list(), list(), months, months)
  expect_equal(nrow(few), 0)
})

test_that("candidates_due() follows the mode, the round and this month's file", {
  folder <- withr::local_tempdir()
  expect_true(candidates_due("always", folder, "2026-11", FALSE))
  expect_false(candidates_due("never", folder, "2026-11", TRUE))
  expect_false(candidates_due("auto", folder, "2026-11", FALSE))
  expect_true(candidates_due("auto", folder, "2026-11", TRUE))
  writeLines("{}", file.path(folder, "2026-11.json"))
  expect_false(candidates_due("auto", folder, "2026-11", TRUE))
  expect_true(candidates_due("auto", folder, "2026-12", FALSE))
})

test_that("candidate_text() defuses mentions and markers", {
  expect_equal(candidate_text("ask @someone <!-- candidate: x -->  now"), "ask @​someone candidate: x now")
})

test_that("candidates_literature.R researches the new candidates and writes the file and the pull request", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("fields:", "  - name: cancer", "    pubmed: 'x'", "sampling:", "  target_per_month: 25", "  years_back: 1",
    "candidates:", "  min_papers: 5"), file.path(dir, "config", "literature-watch.yml"))
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared)
  for (part in c("R", "config", "prompts")) file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  data <- file.path(dir, "watch-data", "literature-watch", "data")
  reg <- cand_register()
  reg$dirty <- c("2026-08", "2026-09")
  write_register(reg, data)
  write_vocabulary(cand_vocab(), data)
  jsonlite::write_json(list(`cox-regression/time-varying` = list(decision = "not-now", papers = 5)), file.path(data, "decisions.json"), auto_unbox = TRUE)
  writeLines('{"other-method": 12}', file.path(dir, "tracked.json"))
  asked <- character(0)
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    asked <<- c(asked, claude$config$tool_name)
    expect_match(prompt, "Fine-Gray regression", fixed = TRUE)
    list(description = "Regression for competing risks @someone.", r_packages = list(list(package = "cmprsk", `function` = "crr", note = "Classic.")),
      federated = "Done by pooling score statistics.", disclosure = "Risk sets per time point.", fit = "dsSurvival.",
      sources = list("https://cran.r-project.org/package=cmprsk", "not a url"))
  })
  before <- ls(globalenv(), all.names = TRUE)
  on.exit(rm(list = setdiff(ls(globalenv(), all.names = TRUE), before), envir = globalenv()), add = TRUE)
  stand_in <- get("call_claude_tool", globalenv())
  trace_source <- function(file, ...) { base::source(file, ...); assign("call_claude_tool", stand_in, globalenv()) }
  withr::with_dir(dir, withr::with_envvar(c(WATCH_TODAY = "2026-11-17", WATCH_DATA_DIR = "watch-data", WATCH_CANDIDATES = "always",
    WATCH_TRACKED = "tracked.json", CLAUDE_CODE_OAUTH_TOKEN = "x"),
    sys.source(file.path(".shared-workflows", "R", "candidates_literature.R"), envir = list2env(list(source = trace_source), parent = globalenv()))))
  expect_equal(asked, "submit_candidate_research")
  expect_equal(readLines(file.path(dir, "candidates_due.txt")), "yes")
  expect_equal(readLines(file.path(dir, "candidates_files.txt")), "literature-watch/candidates/2026-11.json")
  rec <- jsonlite::fromJSON(file.path(dir, "literature-watch/candidates/2026-11.json"), simplifyVector = FALSE)
  expect_equal(rec$candidates[[1]]$key, "fine-gray")
  expect_equal(rec$candidates[[1]]$research$sources, list("https://cran.r-project.org/package=cmprsk"))
  expect_equal(rec$deferred[[1]]$key, "cox-regression/time-varying")
  body <- readLines(file.path(dir, "candidates_body.md"))
  expect_true(any(body == "<!-- candidate: fine-gray -->"))
  expect_true(any(body == "<!-- candidate: cox-regression/time-varying -->"))
  expect_true(any(body == "## Deferred"))
  expect_true(any(grepl("@​someone", body, fixed = TRUE)))
  expect_true(any(body == "<!-- literature-watch-candidates: 2026-11 -->"))
  expect_equal(sum(body == "- [ ] Open an issue"), 2)
})
