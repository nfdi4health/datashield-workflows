# The recently closed issues for the prompt, titles only, so that a report
# of something already fixed or turned down is spotted as a duplicate too.
# Each with why it was closed, as GitHub records it (completed, not
# planned, duplicate). Newest first; how many is settings$max_closed_issues
# (read_issue_for_triage()), and titles keep the cost small.
format_closed_issues <- function(closed_issues) {
  if (is.null(closed_issues) || nrow(closed_issues) == 0) {
    return("(none)")
  }
  reason <- gsub("_", " ", closed_issues$state_reason, fixed = TRUE)
  reason <- ifelse(nzchar(reason), sprintf(" (closed: %s)", reason), " (closed)")
  paste(sprintf("- #%d: %s%s", closed_issues$number, closed_issues$title, reason), collapse = "\n")
}
