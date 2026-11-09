# Other issues as a list for a prompt, one line each, newest first: number,
# title and, for closed ones, why they were closed (completed, not planned,
# duplicate). With `body_chars` > 0, the start of each body follows on the
# same line, cut to that length (the shortlist's view, which has to spot
# related issues from little text); 0 gives titles only (the triage's
# view, which reads the shortlisted issues in full instead).
format_issue_list <- function(issues, body_chars = 0) {
  if (is.null(issues) || nrow(issues) == 0) {
    return("(none)")
  }
  lines <- sprintf("- #%d: %s", issues$number, issues$title)
  if (!is.null(issues$state_reason)) {
    reason <- gsub("_", " ", issues$state_reason, fixed = TRUE)
    lines <- paste0(lines, ifelse(nzchar(reason), sprintf(" (closed: %s)", reason), " (closed)"))
  }
  if (body_chars > 0 && !is.null(issues$body)) {
    start <- trimws(gsub("[[:space:]]+", " ", issues$body))
    cut <- nchar(start) > body_chars
    start[cut] <- paste0(substr(start[cut], 1, body_chars), "...")
    lines <- paste0(lines, ifelse(nzchar(start), paste0(" | ", start), ""))
  }
  paste(lines, collapse = "\n")
}
