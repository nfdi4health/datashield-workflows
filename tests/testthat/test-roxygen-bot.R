# The roxygen bot's per-file review (review_roxygen_file()) through the
# main loop (review_files()), with Claude's answer made up.

local_roxygen_package <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(dir, "R"))
  writeLines(c("#' Old title", "#'", "#' Adds one to its argument.", "#'", "#' @param x a number", "#' @return The number plus one.", "#' @export", "add1 <- function(x) x + 1"),
             file.path(dir, "R", "add1.R"))
  writeLines("x <- 1", file.path(dir, "R", "data.R"))  # no function: skipped
  withr::local_dir(dir, .local_envir = env)
  # build_roxygen_block() reads the tag order from the global `style`.
  assign("style", yaml::read_yaml(file.path(repo_root, "config", "roxygen-style.yml")), envir = globalenv())
  withr::defer(rm("style", envir = globalenv()), envir = env)
  dir
}

roxygen_ctx <- function() {
  list(claude = NULL, bot_ref = NULL, base_rev = "", reviewed_sha = "abc1234", ds_type = "",
       role_text = "", role_text_local = "", accept_reasons = suggestion_reasons("roxygen"),
       code_issue_confidence = c("high", "medium"))
}

test_that("an accepted change is written, other tags kept, and recorded in the state", {
  local_roxygen_package()
  local_global_mock(ask_claude_for_review = function(...) list(
    needs_changes = TRUE, title = "Add one to a number",
    changes = list(list(field = "title", reason = "clarity", explanation = "says what it does")),
    earlier_findings = list(), code_issues = list()
  ))
  out <- review_files(c("R/add1.R", "R/data.R"), decode_suggestion_state(NULL),
                      function(f, parsed, state) review_roxygen_file(f, parsed, state, roxygen_ctx()))
  expect_equal(out$updated, "R/add1.R")
  expect_named(out$results, "R/add1.R")
  lines <- readLines("R/add1.R")
  expect_true("#' @title Add one to a number" %in% lines)
  expect_true(all(c("#' @param x a number", "#' @return The number plus one.", "#' @export", "add1 <- function(x) x + 1") %in% lines))
  applied <- Filter(function(e) identical(e$kind, "applied"), out$state$entries)
  expect_length(applied, 1)
  expect_equal(applied[[1]]$field, "title")
  expect_equal(unname(out$stats[["new"]]), 1L)
})

test_that("a reason that isn't accepted changes nothing but is reported as dropped", {
  local_roxygen_package()
  local_global_mock(ask_claude_for_review = function(...) list(
    needs_changes = TRUE, title = "Add one",
    changes = list(list(field = "title", reason = "style", explanation = "shorter")),
    earlier_findings = list(), code_issues = list()
  ))
  ctx <- roxygen_ctx()
  ctx$accept_reasons <- c("missing", "inaccurate")
  out <- review_files("R/add1.R", decode_suggestion_state(NULL), function(f, parsed, state) review_roxygen_file(f, parsed, state, ctx))
  expect_length(out$updated, 0)
  expect_true("#' Old title" %in% readLines("R/add1.R"))
  expect_equal(vapply(out$state$entries, `[[`, "", "kind"), "dropped")
})

test_that("a failed Claude call leaves the file, warns, and notes it for a retry", {
  local_roxygen_package()
  local_global_mock(ask_claude_for_review = function(...) stop("overloaded"))
  expect_output(
    out <- review_files("R/add1.R", decode_suggestion_state(NULL),
                        function(f, parsed, state) review_roxygen_file(f, parsed, state, roxygen_ctx())),
    "::warning file=R/add1.R,title=Suggestion not made::Claude call failed for R/add1.R: overloaded"
  )
  expect_length(out$updated, 0)
  expect_length(out$state$entries, 0)
  expect_equal(readLines("retry_files.txt"), "R/add1.R")
})
