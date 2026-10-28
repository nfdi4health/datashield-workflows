#!/usr/bin/env Rscript
# Reads files_to_check.txt (produced by the calling workflow), reviews each
# function's roxygen2 documentation for completeness AND accuracy against
# style guidance (and, for DataSHIELD packages, role-specific guidance),
# rewrites the file in place, and lists every rewritten file in
# updated_files.txt for the workflow to commit.
#
# Claude never assembles the final roxygen text: it returns individual prose
# fields (title, description, per-param docs, return, examples), and this
# script deterministically stitches them into one block in the configured
# tag order. Every other tag in the original block (@export, @import,
# @author, @seealso, ...) is carried forward verbatim and never passes
# through Claude at all.
#
# This file only wires environment/config inputs together and runs the main
# loop. All logic lives in R/functions/shared/ and R/functions/roxygen/ —
# one function per file, loaded in bulk below.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "roxygen")), pattern = "\\.R$", full.names = TRUE), source)
use_recorded_answers()  # self-test mode only (input self-test-fixture)

# The run's rules (config/suggestion-policy.yml; the inputs override them).
policy <- suggestion_policy()
accept_reasons <- accepted_reasons(Sys.getenv("ACCEPT_REASONS"), suggestion_reasons("roxygen", accepted = TRUE, policy = policy), "roxygen")
code_issue_confidence <- code_issue_confidence_levels(Sys.getenv("CODE_ISSUE_CONFIDENCE"), policy$possible_bugs$report)
bug_routing <- check_routing(policy$routing$roxygen$possible_bugs, "roxygen possible_bugs")

gh_token   <- Sys.getenv("GH_TOKEN")
repo       <- Sys.getenv("GITHUB_REPOSITORY")
pr_number  <- Sys.getenv("PR_NUMBER")  # empty in a sweep
ds_type    <- check_datashield_type(Sys.getenv("DATASHIELD_TYPE", "none"))
datashield <- !identical(ds_type, "none")
# PR and push runs (empty in a sweep): the reviewed commit, the state before
# this run's changes, and the bot branch whose open PR is built on.
reviewed_sha <- substr(Sys.getenv("REVIEWED_SHA"), 1, 7)
base_rev     <- Sys.getenv("BASE_REV")
sub_branch   <- Sys.getenv("SUB_BRANCH")
builds_on_open_pr <- nzchar(sub_branch) && identical(Sys.getenv("OPEN_SUGGESTION_PR", "add"), "add") && !identical(Sys.getenv("REBUILD"), "true")


style           <- read_config_yaml("config/roxygen-style.yml")
# The Claude client: profile settings, prompt template, access token.
review_claude <- claude_client("roxygen-review", "prompts/roxygen-review-prompt.md")
package_name    <- read_package_name()

# Role guidance depends only on the package — built once. A utility package
# also gets a variant without the demo login example, for its functions
# that don't use DataSHIELD connections (chosen per file below); its demo
# study group is found via the packages it depends on (e.g. dsBaseClient).
role_text <- ""
role_text_local <- ""
if (isTRUE(datashield)) {
  demo_snippet <- NULL
  if (ds_type %in% c("client", "utility")) {
    example_env <- read_config_yaml("config/datashield-example-env.yml", required = FALSE)
    candidates <- if (identical(ds_type, "utility")) {
      c(package_name, read_package_dependencies())
    } else {
      package_name
    }
    group <- find_study_group(example_env, candidates)
    if (is.null(group)) {
      message(sprintf("No compatible demo study group found for package '%s' — skipping canonical example guidance.", package_name))
    } else {
      demo_snippet <- build_demo_login_snippet(package_name, group, example_env$server)
    }
  }
  role_config <- read_config_yaml("config/datashield-role-guidance.yml", required = FALSE)
  role_text <- role_guidance(datashield, ds_type, role_config, demo_snippet)
  role_text_local <- role_guidance(datashield, ds_type, role_config, NULL)
}

files <- readLines("files_to_check.txt")
files <- files[nzchar(files)]

# With an open bot PR to build on, its findings and proposed blocks are
# the starting point: functions are reviewed on top of what it already
# proposes, and its report is merged with this run's findings instead of
# growing an update per run (see dev-notes/roxygen-suggest.md).
pr_body <- if (builds_on_open_pr) {
  fetch_suggestion_pr_body(sub_branch)
} else {
  NULL
}
state <- decode_suggestion_state(pr_body)
# The user's checkboxes (dev-notes/suggestion-choices.md): recorded before
# anything else, so the rebuilt description keeps them.
state <- record_suggestion_choices(state, read_suggestion_choices(pr_body))
# code-issue-confidence "none": no possible bugs — not asked for, and
# earlier ones leave the report too.
with_code_issues <- length(code_issue_confidence) > 0
if (!with_code_issues) {
  state$entries <- Filter(function(e) !identical(e$kind, "bug"), state$entries)
}
bot_ref <- if (!is.null(pr_body)) {
  fetch_bot_branch(sub_branch)
} else {
  NULL
}

# --- Main loop: one review per file (review_roxygen_file()) -----------------

ctx <- list(
  claude = review_claude, bot_ref = bot_ref, base_rev = base_rev, reviewed_sha = reviewed_sha,
  ds_type = ds_type, role_text = role_text, role_text_local = role_text_local,
  accept_reasons = accept_reasons, code_issue_confidence = code_issue_confidence
)
reviewed <- review_files(files, state, function(f, parsed, state) review_roxygen_file(f, parsed, state, ctx))
state <- reviewed$state
stats <- reviewed$stats
updated_files <- reviewed$updated

writeLines(updated_files, "updated_files.txt")

# Everything about the suggestions — applied and not-applied changes and
# possible code bugs — goes into the suggestion PR's description, which is
# rebuilt from all findings on every run (commit-updated-files with
# pr-body-mode "replace"), with a one-line statistic on top that the link
# comment on the originating PR repeats (suggestion_summary.md). Written
# when this run changes files or a bot PR is open; notes alone never open
# one. Without a suggestion PR, possible bugs go where
# routing$roxygen$possible_bugs of the policy file says: by default a
# comment on the originating PR (posted once), or without a PR that
# month's issue (report_sweep_code_issues(); callers grant `issues: write`).
if (length(updated_files) > 0 || !is.null(pr_body)) {
  writeLines(format_roxygen_summary(state), "suggestion_summary.md")
  writeLines(format_roxygen_report(state, list(sha = reviewed_sha, stats = stats), state$legacy), "suggestion_report.md")
} else if (any(vapply(state$entries, function(e) identical(e$kind, "bug"), logical(1)))) {
  bugs <- paste(format_code_issues(state$entries), collapse = "\n")
  if (nzchar(pr_number)) {
    destination <- bug_routing$on_pr
  } else {
    destination <- bug_routing$without_pr
  }
  switch(destination,
    comment = comment_once(pr_number, bugs, "possible code bugs"),
    issue = report_sweep_code_issues(bugs),
    log = message("Possible code bugs (routing: log):\n", bugs)
  )
}
