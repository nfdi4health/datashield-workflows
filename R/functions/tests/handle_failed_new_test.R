# What becomes of a generated test that failed (`fail`: its run result,
# `block_text`: the assembled block, `path`: its test file), given its
# classification (classify_failures(); NULL when the call failed, then
# nothing is reported). Repeats of earlier failures are filtered out
# before (repeated_failure()).
# - a real bug with a confidence in `confidences` (code-issue-confidence):
#   a possible bug in the code; at a confidence in `issue_confidences`
#   (possible_bugs$open_issue of the policy file) also `issue_finding`, which
#   the caller puts into the function's issue (create_bug_issue());
# - anything else: a failed test, commented on the PR when `comment` (a PR
#   run with routing$tests$failed_test_comments), otherwise listed in the
#   report.
# Returns list(kind = "bug" / "failed", entry), or NULL.
handle_failed_new_test <- function(fail, block_text, path, classification, function_name, confidences,
                                   issue_confidences, comment) {
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

  # Commented on the PR: the short explanation; otherwise the report gets
  # the whole failure.
  if (comment) {
    post_test_failure_comment(function_name, block_text, fail$message, classification)
    explanation <- classification$explanation
  } else {
    explanation <- format_test_failure(function_name, block_text, fail$message, classification)
  }
  list(kind = "failed", entry = list(
    file = path, description = fail$description, classification = classification$category, in_report = !comment,
    explanation = explanation
  ))
}
