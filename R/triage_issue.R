#!/usr/bin/env Rscript
# First look at an issue: run by issue-triage.yml once the gate
# (.github/actions/issue-triage-gate) has decided it is needed.
#   1. read the issue as it stands now, the repository's description and
#      the other open and recently closed issues;
#   2. a cheap first call shortlists the issues it may be about, which are
#      read in full with their discussion;
#   3. Claude answers through its tool: a category and short fields;
#   4. R writes the comment, with the marker the gate looks for, and sets
#      the category's label. It never closes an issue.
# The issue's text is untrusted: it only reaches Claude, and what Claude
# says about it is cut down to plain text before it is posted.
# Design: dev-notes/issue-agents.md.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/triage")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "triage")), pattern = "\\.R$", full.names = TRUE), source)

repo <- Sys.getenv("GITHUB_REPOSITORY")
gh_token <- Sys.getenv("GH_TOKEN")
number <- Sys.getenv("ISSUE_NUMBER")

settings <- read_config_yaml("config/issue-triage.yml")
issue <- read_issue_for_triage(number, settings)
auth <- claude_auth()
shortlist <- claude_client("issue-triage-shortlist", "prompts/issue-triage-shortlist-prompt.md", auth)
issue$related <- lapply(shortlist_related_issues(shortlist, issue, settings), read_related_issue, settings = settings)
claude <- claude_client("issue-triage", "prompts/issue-triage-prompt.md", auth)
answer <- ask_claude_for_triage(claude, issue, settings)

posted <- post_github_json(
  sprintf("/repos/%s/issues/%s/comments", repo, number),
  list(body = format_triage_comment(answer, issue, settings)),
  "triage comment"
)
if (!inherits(posted, "httr2_response")) {
  stop("The triage comment could not be posted.", call. = FALSE)
}
apply_triage_label(number, answer$category, issue, settings, Sys.getenv("APPROVAL_LABEL", "bot-proceed"))
apply_suspicious_label(number, answer, issue, settings)
message(sprintf("Issue #%s triaged as %s.", number, answer$category))

# What count-run reads as "this run produced something".
writeLines("triage comment", "updated_files.txt")
