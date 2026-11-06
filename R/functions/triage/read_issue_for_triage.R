# The issue as it stands now, not as the event gave it: the run has waited,
# and the text may have changed. With the repository's description, the
# other open issues with their text (for spotting duplicates; pull
# requests come in the
# same list and are left out), and the last triage with what people have
# written since (triage_history()). Without those the triage still works.
read_issue_for_triage <- function(number) {
  issue <- get_github_json(sprintf("/repos/%s/issues/%s", repo, number))
  if (is.null(issue)) {
    stop(sprintf("Issue #%s could not be read.", number), call. = FALSE)
  }
  open <- get_github_json(sprintf("/repos/%s/issues?state=open&per_page=100", repo)) %||% list()
  open <- Filter(function(x) is.null(x$pull_request) && !identical(as.character(x$number), as.character(number)), open)
  comments <- get_github_json(sprintf("/repos/%s/issues/%s/comments?per_page=100", repo, number)) %||% list()
  history <- triage_history(comments)
  list(
    number = as.integer(number),
    title = issue$title %||% "",
    body = issue$body %||% "",
    labels = vapply(issue$labels %||% list(), function(x) x$name, character(1)),
    author = issue$user$login %||% "",
    repository_description = get_github_json(sprintf("/repos/%s", repo))$description %||% "",
    open_issues = data.frame(
      number = vapply(open, function(x) as.integer(x$number), integer(1)),
      title = vapply(open, function(x) x$title %||% "", character(1)),
      body = vapply(open, function(x) x$body %||% "", character(1))
    ),
    previous_category = history$category,
    previous_comment = history$comment,
    replies = history$replies,
    disputed = read_disputed_issue(history$category, history$comment)
  )
}
