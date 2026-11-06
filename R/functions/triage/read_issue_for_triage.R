# The issue as it stands now, not as the event gave it: the run has waited,
# and the text may have changed. With the repository's description and the
# other open issues (for spotting duplicates; pull requests come in the
# same list and are left out). Without those two the triage still works.
read_issue_for_triage <- function(number) {
  issue <- get_github_json(sprintf("/repos/%s/issues/%s", repo, number))
  if (is.null(issue)) {
    stop(sprintf("Issue #%s could not be read.", number), call. = FALSE)
  }
  open <- get_github_json(sprintf("/repos/%s/issues?state=open&per_page=100", repo)) %||% list()
  open <- Filter(function(x) is.null(x$pull_request) && !identical(as.character(x$number), as.character(number)), open)
  list(
    number = as.integer(number),
    title = issue$title %||% "",
    body = issue$body %||% "",
    repository_description = get_github_json(sprintf("/repos/%s", repo))$description %||% "",
    open_issues = data.frame(
      number = vapply(open, function(x) as.integer(x$number), integer(1)),
      title = vapply(open, function(x) x$title %||% "", character(1))
    )
  )
}
