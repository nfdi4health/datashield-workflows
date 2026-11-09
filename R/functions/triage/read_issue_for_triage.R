# The issue as it stands now, not as the event gave it: the run has waited,
# and the text may have changed. With the repository's description, the
# other open issues and the most recently closed ones
# (settings$max_closed_issues), for the shortlist of related issues (pull
# requests come in the same lists and are left out), and the last triage
# with what people have written since (triage_history(), from all
# comments, as the gate reads them), including the issue an earlier
# verdict called this a duplicate of, with its discussion
# (read_disputed_issue()). Without those the triage still works.
read_issue_for_triage <- function(number, settings) {
  issue <- get_github_json(sprintf("/repos/%s/issues/%s", repo, number))
  if (is.null(issue)) {
    stop(sprintf("Issue #%s could not be read.", number), call. = FALSE)
  }
  not_this <- function(items) {
    Filter(function(x) is.null(x$pull_request) && !identical(as.character(x$number), as.character(number)), items)
  }
  open <- not_this(get_github_json(sprintf("/repos/%s/issues?state=open&per_page=100", repo)) %||% list())
  closed <- list()
  max_closed <- settings$max_closed_issues %||% 0
  if (max_closed > 0) {
    closed <- get_github_json(sprintf(
      "/repos/%s/issues?state=closed&sort=updated&direction=desc&per_page=%d", repo, min(max_closed, 100)
    )) %||% list()
    closed <- not_this(closed)
  }
  comments <- get_github_json_pages(sprintf("/repos/%s/issues/%s/comments", repo, number)) %||% list()
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
    closed_issues = data.frame(
      number = vapply(closed, function(x) as.integer(x$number), integer(1)),
      title = vapply(closed, function(x) x$title %||% "", character(1)),
      body = vapply(closed, function(x) x$body %||% "", character(1)),
      state_reason = vapply(closed, function(x) x$state_reason %||% "", character(1))
    ),
    previous_category = history$category,
    previous_comment = history$comment,
    replies = history$replies,
    disputed = read_disputed_issue(history$category, history$comment, settings),
    hidden_text = count_hidden_text(c(issue$title, issue$body, lapply(history$replies, function(x) x$body)))
  )
}
