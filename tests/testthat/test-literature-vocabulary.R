# The literature watch's vocabulary and "Exists in DataSHIELD?"
# (R/classify_literature.R, R/functions/literature/): Claude and the
# inventory as stand-ins.

paper <- function(pmid, methods, month = "2026-09", usable = TRUE) {
  list(pmid = pmid, month = month, usable = usable, found_by = list(f = list(key = "a", query = "q")),
    methods = lapply(methods, function(m) list(name = m[1], variant = if (length(m) > 1) m[2] else NULL)))
}
register <- function(...) {
  reg <- new.env()
  ps <- list(...)
  reg$papers <- stats::setNames(ps, vapply(ps, function(p) p$pmid, ""))
  reg
}
empty_vocab <- function() list(methods = list(), names = list(), variant_names = list())

test_that("vocabulary_key() makes lower-case hyphenated keys", {
  expect_equal(vocabulary_key("Fisher's exact test"), "fishers-exact-test")
  expect_equal(vocabulary_key("  Cox  (PH) regression! "), "cox-ph-regression")
  expect_equal(vocabulary_key(""), "")
})

test_that("resolve_method() maps names, implied variants and variants that are methods of their own", {
  v <- empty_vocab()
  v$names[["one-way anova"]] <- list(method = "anova", variant = "one-way")
  v$names[["cox regression"]] <- list(method = "cox-regression")
  v$names[["p-value"]] <- list(method = "")
  v$variant_names$anova[["one-way"]] <- list(variant = "one-way")
  v$variant_names[["cox-regression"]][["fine-gray"]] <- list(method = "competing-risks-regression")
  v$variant_names[["cox-regression"]][["stratified"]] <- list(variant = "stratified")
  v$variant_names[["cox-regression"]][["by sex"]] <- list(variant = "")
  expect_equal(resolve_method(v, "one-way anova")$variants, "one-way")
  expect_equal(resolve_method(v, "cox regression", "stratified, by sex")$variants, "stratified")
  expect_equal(resolve_method(v, "cox regression", "fine-gray")$method, "competing-risks-regression")
  expect_true(is.na(resolve_method(v, "p-value")$method))
  unknown <- resolve_method(v, "kaplan-meier estimator", "weighted")
  expect_false(unknown$known)
  expect_equal(unknown$method, "kaplan-meier estimator")
  expect_equal(unknown$variants, "weighted")
})

test_that("name classification answers fill the vocabulary; left-out names stay unclassified", {
  reg <- register(paper("1", list(c("fisher exact test"), c("fisher's exact test"), c("p-value"))),
    paper("2", list(c("fisher exact test", "mid-p"))))
  new <- unclassified_names(reg, empty_vocab())
  expect_equal(new$name[1], "fisher exact test")
  expect_equal(new$papers[1], 2)
  expect_equal(new$variants[1], "mid-p")
  answer <- list(names = list(
    list(name = "fisher exact test", not_a_method = FALSE, method_key = "Fishers exact test", implied_variant = "",
      method_name = "Fisher's exact test", description = "Exact test for 2x2 tables.", keywords = list("Fisher", "exact")),
    list(name = "fisher's exact test", not_a_method = FALSE, method_key = "fishers-exact-test", implied_variant = "",
      method_name = "", description = "", keywords = list()),
    list(name = "invented", not_a_method = TRUE, method_key = "", implied_variant = "", method_name = "", description = "", keywords = list())))
  v <- apply_method_classes(empty_vocab(), answer, new$name, as.Date("2026-11-17"), "fp")
  expect_equal(v$names[["fisher exact test"]]$method, "fishers-exact-test")
  expect_equal(v$names[["fisher's exact test"]]$method, "fishers-exact-test")
  expect_equal(v$methods[["fishers-exact-test"]]$name, "Fisher's exact test")
  expect_equal(unlist(v$methods[["fishers-exact-test"]]$keywords), c("fisher", "exact"))
  expect_null(v$names[["invented"]])
  expect_equal(unclassified_names(reg, v)$name, "p-value")
  expect_equal(unclassified_variants(reg, v)$variant, "mid-p")
})

test_that("variant classification answers add variants, methods of their own and non-variants", {
  v <- empty_vocab()
  v$methods[["cox-regression"]] <- list(name = "Cox regression")
  v$names[["cox regression"]] <- list(method = "cox-regression")
  answer <- list(variants = list(
    list(variant = "time-dependent covariates", not_a_variant = FALSE, own_method = FALSE, variant_key = "time-varying-covariates",
      variant_name = "time-varying covariates", method_key = "", method_name = "", description = "", keywords = list()),
    list(variant = "fine-gray", not_a_variant = FALSE, own_method = TRUE, variant_key = "", variant_name = "",
      method_key = "competing-risks-regression", method_name = "Competing risks regression", description = "Fine-Gray.", keywords = list("competing")),
    list(variant = "by sex", not_a_variant = TRUE, own_method = FALSE, variant_key = "", variant_name = "", method_key = "",
      method_name = "", description = "", keywords = list())))
  v <- apply_variant_classes(v, "cox-regression", answer, c("time-dependent covariates", "fine-gray", "by sex"), as.Date("2026-11-17"), "fp")
  expect_equal(v$methods[["cox-regression"]]$variants[["time-varying-covariates"]]$name, "time-varying covariates")
  expect_equal(v$variant_names[["cox-regression"]][["fine-gray"]]$method, "competing-risks-regression")
  expect_equal(v$methods[["competing-risks-regression"]]$name, "Competing risks regression")
  expect_equal(v$variant_names[["cox-regression"]][["by sex"]]$variant, "")
  reg <- register(paper("1", list(c("cox regression", "fine-gray"))), paper("2", list(c("cox regression", "time-dependent covariates, by sex"))))
  counts <- method_paper_counts(reg, v)
  expect_equal(counts$papers[counts$method == "competing-risks-regression" & counts$variant == ""], 1)
  expect_equal(counts$papers[counts$method == "cox-regression" & counts$variant == "time-varying-covariates"], 1)
})

inventory <- data.frame(
  package = c("dsSurvivalClient", "dsBaseClient", "dsNewClient"),
  fn = c("ds.coxph", "ds.glm", "ds.finegray"),
  title = c("Distributed Cox Proportional Hazards Model", "Fits Generalized Linear Model", "Competing risks"),
  description = c("Runs a distributed Cox proportional hazards model.", "Fits a GLM on data from several sources.",
    "Fine-Gray regression for competing risks."),
  status = c("production", "production", "development"), stringsAsFactors = FALSE)

test_that("preselect_functions() ranks by shared words, function names counting double", {
  c1 <- preselect_functions(inventory, c("Cox regression", "proportional hazards", "coxph"), 2)
  expect_equal(c1$fn[1], "ds.coxph")
  expect_equal(nrow(preselect_functions(inventory, c("kaplan-meier", "survival curve"))), 0)
})

test_that("check_exists_answer() keeps verdicts only with a listed function and a quote from its documentation", {
  ok <- check_exists_answer(list(verdict = "yes", `function` = "dsSurvivalClient::ds.coxph",
    quote = "distributed  Cox proportional hazards", note = ""), inventory, "h", as.Date("2026-11-17"), "fp")
  expect_equal(ok$verdict, "yes")
  expect_equal(ok[["function"]], "dsSurvivalClient::ds.coxph")
  wrong <- check_exists_answer(list(verdict = "yes", `function` = "dsSurvivalClient::ds.coxph",
    quote = "supports time-varying covariates", note = ""), inventory, "h", as.Date("2026-11-17"), "fp")
  expect_equal(wrong$verdict, "unconfirmed")
  missing <- check_exists_answer(list(verdict = "partial", `function` = "dsX::ds.nothing", quote = "Cox", note = ""),
    inventory, "h", as.Date("2026-11-17"), "fp")
  expect_equal(missing$verdict, "unconfirmed")
  dev <- check_exists_answer(list(verdict = "yes", `function` = "dsNewClient::ds.finegray", quote = "Fine-Gray regression", note = ""),
    inventory, "h", as.Date("2026-11-17"), "fp")
  expect_equal(dev$verdict, "development")
  expect_equal(dev$match, "yes")
  expect_equal(exists_label(list(methods = list(x = list(exists = dev))), "x"), "no (in development: `dsNewClient::ds.finegray`)")
  none <- check_exists_answer(list(verdict = "none", `function` = "", quote = "", note = "Nothing."), inventory, "h", as.Date("2026-11-17"), "fp")
  expect_equal(none$verdict, "none")
})

test_that("exists_round() asks once, gives none without candidates, and asks again only when the candidates change", {
  v <- empty_vocab()
  v$methods[["cox-regression"]] <- list(name = "Cox regression", keywords = list("cox", "proportional hazards"))
  v$methods[["kaplan-meier"]] <- list(name = "Kaplan-Meier estimator", keywords = list("kaplan", "survival curve"))
  v$names[["cox"]] <- list(method = "cox-regression")
  v$names[["km"]] <- list(method = "kaplan-meier")
  reg <- register(paper("1", list("cox", "km")), paper("2", list("cox", "km")), paper("3", list("cox", "km")))
  settings <- list(exists = list(min_papers = 3, candidates = 5, batch = 5))
  asked <- 0
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    asked <<- asked + 1
    expect_match(prompt, "dsSurvivalClient::ds.coxph (status: production)", fixed = TRUE)
    list(methods = list(list(id = "m1", verdict = "yes", `function` = "dsSurvivalClient::ds.coxph",
      quote = "Distributed Cox Proportional Hazards Model", note = "")))
  })
  claude <- list(prompt = "{{METHODS}}", config = list())
  r <- exists_round(v, reg, claude, inventory, settings, as.Date("2026-11-17"), "fp", 10)
  expect_equal(asked, 1)
  expect_equal(r$vocab$methods[["cox-regression"]]$exists$verdict, "yes")
  expect_equal(r$vocab$methods[["kaplan-meier"]]$exists$verdict, "none")
  expect_equal(r$vocab$methods[["kaplan-meier"]]$exists$by, "R")
  again <- exists_round(r$vocab, reg, claude, inventory, settings, as.Date("2026-11-18"), "fp", 10)
  expect_equal(asked, 1)
  inv2 <- rbind(inventory, data.frame(package = "dsSurvivalClient", fn = "ds.coxphSLMA", title = "Cox regression per study",
    description = "Cox proportional hazards per study, pooled by meta-analysis.", status = "production"))
  exists_round(again$vocab, reg, claude, inv2, settings, as.Date("2026-11-19"), "fp", 10)
  expect_equal(asked, 2)
})

test_that("method_table() merges names the vocabulary maps to one method", {
  v <- empty_vocab()
  v$methods[["fishers-exact-test"]] <- list(name = "Fisher's exact test")
  v$names[["fisher exact test"]] <- list(method = "fishers-exact-test")
  v$names[["fisher's exact test"]] <- list(method = "fishers-exact-test")
  v$names[["p-value"]] <- list(method = "")
  ps <- list(paper("1", list("fisher exact test", "p-value")), paper("2", list("fisher's exact test")))
  t <- method_table(ps, "2026", "2026-09", vocab = v)
  expect_equal(t$method, "fishers-exact-test")
  expect_equal(t$papers, 2)
  section <- format_method_section("All", ps, "2026", "2026-09", vocab = v)
  expect_true(any(grepl("| Fisher's exact test | 100% | 2 | 100% | – | – |", section, fixed = TRUE)))
})

test_that("classify_literature.R classifies names and variants, checks existence and writes the vocabulary", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "config"))
  writeLines(c("exists:", "  min_papers: 2", "  functions_url: https://example.org/functions.json",
    "  packages_url: https://example.org/packages.csv"), file.path(dir, "config", "literature-watch.yml"))
  shared <- file.path(dir, ".shared-workflows")
  dir.create(shared)
  for (part in c("R", "config", "prompts")) file.copy(file.path(repo_root, part), shared, recursive = TRUE)
  data <- file.path(dir, "watch-data", "literature-watch", "data")
  reg <- register(paper("1", list(c("cox regression", "time-dependent covariates"), c("p-value"))),
    paper("2", list(c("cox proportional hazards model"))))
  write_register(local({ reg$dirty <- "2026-09"; reg }), data)
  functions <- jsonlite::toJSON(data.frame(package = c("dsSurvivalClient", "dsOld", "dsSurvival"),
    function_name = c("ds.coxph", "ds.cox", "coxphDS.assign"),
    architecture_type = c("client", "client", "other"), function_type = "aggregate",
    title = c("Distributed Cox Proportional Hazards Model", "Old Cox", "Server Cox"), description = c("Runs Cox.", "Old.", "Server side Cox."),
    category = "", status = "", test_file = TRUE))
  packages <- "name|description|github_link|cran_link|status\ndsSurvivalClient | x | https://github.com/a/b | | production\ndsOld | x | | | retired"
  mock <- function(req) {
    body <- if (grepl("functions", req$url)) functions else packages
    httr2::response(status_code = 200, headers = list("content-type" = "text/plain"), body = charToRaw(as.character(body)))
  }
  tools <- character(0)
  local_global_mock(call_claude_tool = function(claude, tool, prompt) {
    tools <<- c(tools, claude$config$tool_name)
    switch(claude$config$tool_name,
      submit_method_classes = list(names = list(
        list(name = "cox regression", not_a_method = FALSE, method_key = "cox-regression", implied_variant = "",
          method_name = "Cox regression", description = "Survival regression.", keywords = list("cox", "proportional hazards")),
        list(name = "cox proportional hazards model", not_a_method = FALSE, method_key = "cox-regression", implied_variant = "",
          method_name = "", description = "", keywords = list()),
        list(name = "p-value", not_a_method = TRUE, method_key = "", implied_variant = "", method_name = "", description = "", keywords = list()))),
      submit_variant_classes = {
        expect_match(prompt, "time-dependent covariates (1 papers)", fixed = TRUE)
        list(variants = list(list(variant = "time-dependent covariates", not_a_variant = FALSE, own_method = FALSE,
          variant_key = "time-varying-covariates", variant_name = "time-varying covariates", method_key = "", method_name = "",
          description = "", keywords = list())))
      },
      submit_exists_verdicts = {
        expect_false(grepl("dsOld", prompt))
        expect_false(grepl("coxphDS.assign", prompt))
        list(methods = list(list(id = "m1", verdict = "yes", `function` = "dsSurvivalClient::ds.coxph",
          quote = "Distributed Cox Proportional Hazards Model", note = "")))
      })
  })
  before <- ls(globalenv(), all.names = TRUE)
  on.exit(rm(list = setdiff(ls(globalenv(), all.names = TRUE), before), envir = globalenv()), add = TRUE)
  stand_in <- get("call_claude_tool", globalenv())
  trace_source <- function(file, ...) { base::source(file, ...); assign("call_claude_tool", stand_in, globalenv()) }
  withr::with_dir(dir, withr::with_envvar(c(WATCH_TODAY = "2026-11-17", WATCH_DATA_DIR = "watch-data", CLAUDE_CODE_OAUTH_TOKEN = "x"),
    httr2::with_mocked_responses(mock, sys.source(file.path(".shared-workflows", "R", "classify_literature.R"),
      envir = list2env(list(source = trace_source), parent = globalenv())))))
  v <- read_vocabulary(data)
  expect_equal(v$names[["cox proportional hazards model"]]$method, "cox-regression")
  expect_equal(v$names[["p-value"]]$method, "")
  expect_equal(v$methods[["cox-regression"]]$exists$verdict, "yes")
  expect_equal(v$methods[["cox-regression"]]$exists[["function"]], "dsSurvivalClient::ds.coxph")
  expect_equal(v$methods[["cox-regression"]]$variants[["time-varying-covariates"]]$name, "time-varying covariates")
  expect_equal(tools, c("submit_method_classes", "submit_variant_classes", "submit_exists_verdicts"))
  readers <- utils::read.csv(file.path(data, "readers.csv"))
  expect_setequal(readers$group, c("names", "variants", "exists"))
})
