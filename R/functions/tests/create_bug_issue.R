# Reports a function's generated tests that failed on a likely genuine
# bug (classified real_bug, at an issue confidence) in a GitHub issue — more
# durable than a PR comment: it survives a closed suggestion PR (see
# dev-notes/test-suggest.md). One issue per function, one post per run:
# `findings` is a list of list(description, block, message, explanation),
# all of the function's such tests of this run.
# - No open issue yet: one is opened with the intro once and, per test, its
#   name and Claude's explanation; test code and error output folded away.
# - An open issue: only a short "still failing" comment naming the tests —
#   the issue already explains the bug; an identical comment (the same
#   tests) isn't posted again (post_issue_once(), comment_once()).
# Returns the issue's URL, or NULL.
create_bug_issue <- function(function_name, findings) {
  title <- sprintf("Possible bug found by generated test: %s", function_name)
  tests <- "1 test"
  if (length(findings) > 1) {
    tests <- sprintf("%d tests", length(findings))
  }

  details <- character(0)
  for (f in findings) {
    details <- c(details,
      sprintf("### %s", f$description),
      "",
      f$explanation,
      "",
      "<details><summary>Generated test and failure output</summary>",
      "",
      "```r",
      f$block,
      "```",
      "",
      "```",
      f$message,
      "```",
      "",
      "</details>",
      ""
    )
  }
  body <- c(
    sprintf(
      "%s written by the test suggestion workflow failed against `%s`, classified as a likely genuine bug (not a bad test or an environment issue). The tests were not committed; this issue is the only automatic action taken.",
      tests, function_name
    ),
    "",
    details
  )

  comment <- c(
    sprintf("Still failing in a later review (%s):", tests),
    "",
    vapply(findings, function(f) sprintf("- %s", f$description), character(1))
  )

  post_issue_once(title, paste(body, collapse = "\n"), function_name, comment = paste(comment, collapse = "\n"))
}
