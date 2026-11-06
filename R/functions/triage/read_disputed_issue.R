# The issue an earlier triage called this one a duplicate of, in full, so
# that an objection can be checked against what that issue really says:
# the list of open issues only has titles. Found through the line
# format_triage_comment() writes. NULL if the last verdict was something
# else, no issue was named, or it can't be read; the triage still works.
read_disputed_issue <- function(category, comment) {
  if (!identical(category, "duplicate") || is.null(comment)) {
    return(NULL)
  }
  found <- regmatches(comment, regexec("Possibly the same as #([0-9]+)\\.", comment))[[1]]
  if (length(found) < 2) {
    return(NULL)
  }
  issue <- get_github_json(sprintf("/repos/%s/issues/%s", repo, found[2]))
  if (is.null(issue)) {
    return(NULL)
  }
  list(number = as.integer(found[2]), title = issue$title %||% "", body = issue$body %||% "")
}
