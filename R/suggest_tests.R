#!/usr/bin/env Rscript
# Reads files_to_check.txt (produced by the calling workflow) and, for each
# function's (first) file, reviews its tests with Claude: new real,
# runnable test_that() blocks where they add value, and decisions on
# existing tests — update an outdated one, delete an obsolete one, or
# report one that points to a possible bug. Claude sees the existing
# tests' current results and the history evidence (build_test_evidence())
# to tell an outdated test from a bug.
#
# An R file can have several test files (test-<name>.R, or
# test-<category>-<name>.R in repositories that sort tests by purpose,
# detect_test_scheme(); <name> is the R file's name, test_file_name());
# each change stays in its own file.
#
# Nothing is trusted unchecked: new tests pass filter_generated_tests(),
# decisions on existing tests pass review_existing_tests(), then every new
# and updated test is actually run. Each test file is rewritten from its
# original content with only what passed (plus deletions) and listed in
# updated_files.txt for the workflow to propose; a failing new test is
# classified (bad_test / real_bug / env_misconfiguration) and surfaced,
# a failing update keeps the original test and is reported.
#
# Sibling to R/suggest_roxygen.R — same conventions: orchestration only
# here, logic in R/functions/shared/ and R/functions/tests/, Claude call
# settings in config/claude.yml,
# deterministic field-based assembly (Claude never writes final test_that()
# syntax directly). See dev-notes/test-suggest.md and
# dev-notes/suggestion-thresholds.md for the design reasoning.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "tests")), pattern = "\\.R$", full.names = TRUE), source)
use_recorded_answers()  # self-test mode only (input self-test-fixture)

# The run's rules (config/suggestion-policy.yml; the inputs override them):
# accepted reasons, max new tests, which possible bugs in the code are
# reported (by Claude's confidence) and which open an issue, and where
# findings go without a bot PR.
policy <- suggestion_policy()
accept_reasons <- accepted_reasons(Sys.getenv("ACCEPT_REASONS"), suggestion_reasons("tests", accepted = TRUE, policy = policy), "tests")
max_new_tests <- as.integer(policy$tests$max_new_tests)
code_issue_confidence <- code_issue_confidence_levels(Sys.getenv("CODE_ISSUE_CONFIDENCE"), policy$possible_bugs$report)
issue_confidence <- unlist(policy$possible_bugs$open_issue)
report_routing <- check_routing(policy$routing$tests$report, "tests report")

gh_token   <- Sys.getenv("GH_TOKEN")
repo       <- Sys.getenv("GITHUB_REPOSITORY")
pr_number  <- Sys.getenv("PR_NUMBER")
base_rev   <- Sys.getenv("BASE_REV")  # state before this run's changes; empty in a sweep
is_sweep   <- !nzchar(pr_number)  # no PR to comment on (a sweep, or a push without a PR)
# PR and push runs (empty in a sweep): the reviewed commit and the bot
# branch whose open PR is built on.
reviewed_sha <- substr(Sys.getenv("REVIEWED_SHA"), 1, 7)
sub_branch   <- Sys.getenv("SUB_BRANCH")
builds_on_open_pr <- nzchar(sub_branch) && identical(Sys.getenv("OPEN_SUGGESTION_PR", "add"), "add") && !identical(Sys.getenv("REBUILD"), "true")
ds_type    <- check_datashield_type(Sys.getenv("DATASHIELD_TYPE", "none"))
datashield <- !identical(ds_type, "none")
# Client packages always test against DSLite; utility packages only for
# functions that use DataSHIELD connections (decided per function below).
may_use_dslite <- isTRUE(datashield) && ds_type %in% c("client", "utility")
# Whether a function needing connections gets a fresh DSLite setup
# (decide_dslite_setup()).
dslite_setup_mode <- Sys.getenv("DSLITE_SETUP", "auto")
check_dslite_setup_mode(dslite_setup_mode)

# The Claude clients (profile settings, prompt template), sharing one
# access token.
claude_access <- claude_auth()
review_claude <- claude_client("test-review", "prompts/test-review-prompt.md", claude_access)
classification_claude <- claude_client("test-failure-classification", "prompts/test-failure-classification-prompt.md", claude_access)
test_role_guidance                    <- read_config_yaml("config/test-role-guidance.yml")
category_meanings                     <- read_config_yaml("config/test-categories.yml", required = FALSE)$categories
package_name                          <- read_package_name()

# DSLite's built-in canned datasets need no server/credentials/per-package
# matching — unlike datashield-example-env.yml, which describes the real
# Opal demo server for roxygen's usage examples, a different scenario.
dslite_datasets <- if (may_use_dslite) {
  read_config_yaml("config/dslite-canned-datasets.yml", required = FALSE)$datasets
} else {
  NULL
}


files <- readLines("files_to_check.txt")
files <- files[nzchar(files)]

# With an open bot PR to build on, its findings and the test files it
# proposes are the starting point: they are put in place before anything
# runs, so its tests count as existing, and its report is merged with this
# run's findings instead of growing an update per run (see
# dev-notes/test-suggest.md).
pr_body <- if (builds_on_open_pr) {
  fetch_suggestion_pr_body(sub_branch)
} else {
  NULL
}
state <- decode_suggestion_state(pr_body)
# The user's checkboxes (dev-notes/suggestion-choices.md): recorded before
# anything else, so the rebuilt description keeps them.
state <- record_suggestion_choices(state, read_suggestion_choices(pr_body))
# code-issue-confidence "none": no possible bugs, also not earlier ones.
if (length(code_issue_confidence) == 0) {
  state$entries <- Filter(function(e) !identical(e$kind, "bug"), state$entries)
}
bot_ref <- if (!is.null(pr_body)) {
  fetch_bot_branch(sub_branch)
} else {
  NULL
}
bot_tests <- materialize_bot_tests(bot_ref, base_rev)

# How the repository names its test files (test-<name>.R or
# test-<category>-<name>.R, <name> being the R file's name) — once per
# run. The names to recognise: the R files' names (test_file_name()), plus
# the function names, which other repositories' category files may use.
scheme <- detect_test_scheme(unique(c(test_file_name(list.files("R", pattern = "[.][Rr]$")), package_function_names())))

# Structure of the test data the package's setup/helper files create —
# once per run, in a separate R process.
test_data <- summarize_test_data(test_support_files(), file.path(functions_dir, "tests"))
message("Test data:\n", test_data)

# --- Main loop: one review per file (review_test_file()) --------------------

ctx <- list(
  review_claude = review_claude, classification_claude = classification_claude,
  bot_tests = bot_tests, reviewed_sha = reviewed_sha, base_rev = base_rev,
  datashield = datashield, ds_type = ds_type, may_use_dslite = may_use_dslite,
  dslite_setup_mode = dslite_setup_mode, dslite_datasets = dslite_datasets,
  test_role_guidance = test_role_guidance, scheme = scheme, category_meanings = category_meanings,
  test_data = test_data,
  cache_prompt = length(files) > 1,   # the prompt cache only pays with a second call in the run
  max_new_tests = max_new_tests, accept_reasons = accept_reasons,
  code_issue_confidence = code_issue_confidence, issue_confidence = issue_confidence, package_name = package_name,
  comment_failures = !is_sweep && isTRUE(policy$routing$tests$failed_test_comments)
)
reviewed <- review_files(files, state, function(f, parsed, state) review_test_file(f, parsed, state, ctx))
state <- reviewed$state
stats <- reviewed$stats
updated_files <- reviewed$updated
new_total <- sum(vapply(reviewed$results, function(r) r$new_kept, numeric(1)))  # new tests kept, for ensure_testthat_setup()
# Findings that belong to no function (testthat setup, Suggests).
merge_run <- function(run) {
  merged <- merge_test_findings(state, "", run, reviewed_sha)
  state <<- merged$state
  stats <<- stats + merged$stats
}

# Proposed tests only count if R CMD check runs them: set up testthat in
# packages that don't have it yet.
testthat_setup <- if (new_total > 0) {
  ensure_testthat_setup(package_name)
} else {
  character(0)
}
updated_files <- c(updated_files, testthat_setup)
if (length(testthat_setup) > 0) {
  merge_run(list(setups = testthat_setup))
}

# Packages the proposed tests use but DESCRIPTION doesn't declare go into
# Suggests, so R CMD check doesn't warn about them.
added_packages <- declare_test_packages(package_name, grep("^tests/", updated_files, value = TRUE))
if (length(added_packages) > 0) {
  updated_files <- unique(c(updated_files, "DESCRIPTION"))
  merge_run(list(dependencies = added_packages))
  message("Added to Suggests (used by the proposed tests): ", paste(added_packages, collapse = ", "))
}

writeLines(updated_files, "updated_files.txt")
restore_unproposed_files(bot_tests$materialized, updated_files)

# One-line summary of the open findings: in the link comment on the
# originating PR (read by commit-updated-files from suggestion_summary.md)
# and on top of the suggestion PR's description, which is rebuilt from all
# findings on every run (pr-body-mode "replace"). Written when this run
# changes files or a bot PR is open; without one, notes and sweep failures
# still get published (publish_test_report()). Functions left untested
# (dslite-setup: never) are listed when there is a report anyway, but
# don't make one on their own: the repository chose that, and a comment
# or issue on every run would be noise.
has_pr <- length(updated_files) > 0 || !is.null(pr_body)
open_kinds <- vapply(Filter(function(e) identical(e$status, "active"), state$entries), function(e) e$kind, character(1))
if (length(updated_files) > 0) {
  writeLines(format_test_summary(state), "suggestion_summary.md")
}
if (has_pr || any(open_kinds %in% c("note", "bug")) || any(vapply(state$entries, function(e) isTRUE(e$in_report), logical(1)))) {
  report <- format_test_report(state, list(sha = reviewed_sha, stats = stats), state$legacy)
  publish_test_report(report, has_pr = has_pr, routing = report_routing)
}
