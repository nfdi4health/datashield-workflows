# Smoke test with real Claude calls (decided 2026-11-13): the roxygen and
# test bots' entry scripts on the made-up package tests/fixtures/r-package,
# as in test-entry-scripts.R, but Claude answers for real, through Claude
# Code on the owner's subscription (CLAUDE_CODE_OAUTH_TOKEN). GitHub is
# still answered locally (404), nothing is pushed or posted. It checks
# what recorded answers can't: that the models in config/claude.yml are
# available, that each tool schema is accepted and answered, and that
# the answers fit what R expects. Run by .github/workflows/smoke-test.yml:
#   Rscript tests/smoke.R
# Skipped without CLAUDE_CODE_OAUTH_TOKEN.

source(file.path(testthat::test_path(), "..", "testthat", "helper-load.R"), local = TRUE)

smoke_env <- function() c(
  ANTHROPIC_API_KEY = "", GH_TOKEN = "", GITHUB_REPOSITORY = "me/fixturepkg",
  PR_NUMBER = "", SUB_BRANCH = "", REVIEWED_SHA = "abc1234def", BASE_REV = "", DATASHIELD_TYPE = "none"
)

# A Claude call that failed leaves a retry note (note_retry_file()); the
# report must exist and no call may have failed.
expect_calls_answered <- function(dir) {
  retry <- file.path(dir, "retry_files.txt")
  failed <- if (file.exists(retry)) readLines(retry) else character(0)
  testthat::expect_length(failed, 0)
  testthat::expect_true(file.exists(file.path(dir, "suggestion_report.md")))
}

testthat::test_that("the roxygen bot gets real answers for the fixture package", {
  testthat::skip_if_not(nzchar(Sys.getenv("CLAUDE_CODE_OAUTH_TOKEN")), "no CLAUDE_CODE_OAUTH_TOKEN")
  dir <- local_fixture("r-package")
  writeLines(c("R/add1.R", "R/clamp.R"), file.path(dir, "files_to_check.txt"))
  run_entry_script_mocked("suggest_roxygen.R", dir, smoke_env())
  expect_calls_answered(dir)
  #### add1 has no @return: a working review proposes one
  testthat::expect_true(any(grepl("@return", readLines(file.path(dir, "R", "add1.R")), fixed = TRUE)))
})

testthat::test_that("the test bot gets real answers for the fixture package", {
  testthat::skip_if_not(nzchar(Sys.getenv("CLAUDE_CODE_OAUTH_TOKEN")), "no CLAUDE_CODE_OAUTH_TOKEN")
  dir <- local_fixture("r-package")
  writeLines(c("R/add1.R", "R/clamp.R"), file.path(dir, "files_to_check.txt"))
  run_entry_script_mocked("suggest_tests.R", dir, smoke_env())
  expect_calls_answered(dir)
  testthat::expect_true(file.exists(file.path(dir, "updated_files.txt")))
})
