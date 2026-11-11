# Opens an issue `title` with `body` — unless an open issue with that exact
# title exists: then `comment` (by default `body`) goes there as a comment,
# unless the issue or one of its comments already says exactly that
# (comment_once()). So a bot finding that comes up again, e.g. after its
# suggestion PR was closed, doesn't open a second issue; a caller whose
# issue already explains the finding passes a short `comment` instead of
# repeating it. Returns the issue's URL (for a link in the report), or NULL
# if it couldn't be opened. Needs `issues: write` in the caller.
#
# A new issue is opened with ISSUE_TOKEN (the App's) when the workflow has
# one: issues opened with GITHUB_TOKEN start no workflow, so triage would
# never see them. If that fails (no App, token expired in a long run), it
# is opened with GH_TOKEN as before.
post_issue_once <- function(title, body, context, comment = body) {
  open <- get_github_json(sprintf("/repos/%s/issues?state=open&per_page=100", repo))
  existing <- Find(function(i) identical(i$title, title) && is.null(i$pull_request), open)
  if (is.null(existing)) {
    issue_token <- Sys.getenv("ISSUE_TOKEN")
    resp <- NULL
    if (nzchar(issue_token)) {
      resp <- post_github_json(sprintf("/repos/%s/issues", repo), list(title = title, body = body), context, token = issue_token)
    }
    if (!inherits(resp, "httr2_response")) {
      resp <- post_github_json(sprintf("/repos/%s/issues", repo), list(title = title, body = body), context)
    }
    url <- tryCatch(httr2::resp_body_json(resp)$html_url, error = function(e) NULL)
    return(invisible(url))
  }
  if (identical(trimws(existing$body %||% ""), trimws(comment))) {
    message(sprintf("Issue #%s \"%s\" already says this — nothing added (%s).", existing$number, title, context))
  } else {
    message(sprintf("Issue #%s \"%s\" is already open — adding to it (%s).", existing$number, title, context))
    comment_once(existing$number, comment, context)
  }
  invisible(existing$html_url)
}
