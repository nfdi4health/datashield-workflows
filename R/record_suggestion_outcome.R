#!/usr/bin/env Rscript
# Records what became of a roxygen or test bot PR's suggestions when the
# PR is closed or merged (v1 item L, dev-notes/feedback-loop.md): run by
# suggestion-choices.yml on `pull_request: closed`, in a checkout of the
# base branch (the merged result) with the bot branch's last commit
# fetched. Collecting only — nothing is analysed or sent anywhere; the
# record is a hidden comment added to the PR's own description:
#   <!-- bot-suggest-outcome: <base64 JSON> -->
# with the final box per finding, accepted / declined / closed, whether an
# accepted suggestion was edited before merging (both texts), the review
# line comments on the findings' files, and the run's provenance
# (provenance_footer()'s marker, if the report has one).
# Writes new_body.md, or nothing if the PR has no findings to record or
# already has a record.
#
# Env: KIND ("tests" or "docs"), PR_BODY_FILE, MERGED ("true"/"false"),
# BOT_SHA (the bot branch's last commit), COMMENTS_FILE (review comments
# as JSON from the GitHub API), FINAL_REV (default HEAD).

functions_dir <- if (dir.exists("R/functions")) "R/functions" else ".shared-workflows/R/functions"
for (dir in c("shared", "tests", "roxygen", "choices")) {
  for (f in list.files(file.path(functions_dir, dir), pattern = "\\.R$", full.names = TRUE)) {
    source(f)
  }
}

body <- paste(readLines(Sys.getenv("PR_BODY_FILE"), warn = FALSE), collapse = "\n")
if (grepl("<!-- bot-suggest-outcome:", body, fixed = TRUE)) {
  message("This PR already has an outcome record.")
  quit(save = "no")
}
if (identical(suggestion_policy()$outcome_record, FALSE)) {
  message("Outcome records are turned off (outcome_record in config/suggestion-policy.yml).")
  quit(save = "no")
}
state <- record_suggestion_choices(decode_suggestion_state(body), read_suggestion_choices(body))
choices <- lapply(state$entries, suggestion_choice)
entries <- state$entries[vapply(choices, function(ch) !identical(ch, "none"), logical(1))]
if (length(entries) == 0) {
  message("No suggestions to record.")
  quit(save = "no")
}
merged <- identical(Sys.getenv("MERGED"), "true")
final_rev <- Sys.getenv("FINAL_REV", "HEAD")
bot_rev <- Sys.getenv("BOT_SHA")
comments_file <- Sys.getenv("COMMENTS_FILE")
comments <- if (nzchar(comments_file) && file.exists(comments_file)) {
  jsonlite::fromJSON(comments_file, simplifyVector = FALSE)
} else {
  list()
}

provenance <- regmatches(body, regexpr("<!-- bot-suggest-provenance: .*? -->", body))
record <- list(
  version = 1L,
  kind = Sys.getenv("KIND"),
  merged = merged,
  recorded = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  provenance = if (length(provenance) > 0) jsonlite::fromJSON(sub("^<!-- bot-suggest-provenance: (.*) -->$", "\\1", provenance), simplifyVector = FALSE),
  findings = lapply(entries, function(e) finding_outcome(e, suggestion_choice(e), merged, final_rev, bot_rev)),
  comments = match_review_comments(comments, entries)
)
counts <- table(vapply(record$findings, function(f) f$outcome, character(1)))
edited <- sum(vapply(record$findings, function(f) isTRUE(f$edited), logical(1)))
message(sprintf("Outcome: %s; %d edited before merging.", paste(names(counts), counts, sep = " ", collapse = ", "), edited))
writeLines(paste0(body, "\n", encode_outcome_record(record)), "new_body.md")
