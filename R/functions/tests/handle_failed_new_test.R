# What becomes of a generated test that failed (`fail`: its run result,
# `block_text`: the assembled block, `path`: its test file), given its
# classification (classify_failures(); NULL when the call failed, then
# nothing is reported). Repeats of earlier failures are filtered out
# before (repeated_failure()).
# - a real bug with a confidence in `confidences` (code-issue-confidence):
#   a possible bug in the code; at a confidence in `issue_confidences`
#   (possible_bugs$open_issue of the policy file) also `issue_finding`, which
#   the caller puts into the function's issue (create_bug_issue());
# - anything else (the test's own fault, or the test environment's): a
#   failed test, listed in the suggestion report with one line each and
#   the code folded (format_test_failure()); never a PR comment, since it
#   needs nothing from the author (user, 2026-11-12).
# Returns list(kind = "bug" / "failed", entry), or NULL.
handle_failed_new_test <- function(fail, block_text, path, classification, function_name, confidences,
                                   issue_confidences) {
  if (is.null(classification)) {
    return(NULL)
  }

  if (identical(classification$category, "real_bug") && isTRUE(classification$confidence %in% confidences)) {
    # For the issue (create_bug_issue()), reported once per function and
    # run by the caller together with the function's other such tests.
    finding <- NULL
    if (isTRUE(classification$confidence %in% issue_confidences)) {
      finding <- list(
        description = fail$description, block = block_text, message = fail$message,
        explanation = classification$explanation
      )
    }
    return(list(kind = "bug", issue_finding = finding, entry = list(
      file = path, description = fail$description, origin = "failure", explanation = classification$explanation,
      confidence = classification$confidence, issue = ""
    )))
  }

  list(kind = "failed", entry = list(
    file = path, description = fail$description, classification = classification$category, in_report = TRUE,
    explanation = classification$explanation, details = format_test_failure(block_text, fail$message)
  ))
}
