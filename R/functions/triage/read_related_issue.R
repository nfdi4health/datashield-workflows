# One issue the triage compares against, with its discussion: title, state,
# body and people's comments (bots left out), oldest first, as text for the
# prompt. Cut to settings$max_related_chars: the body keeps at most a third
# of it, the rest goes to the comments, newest kept, since a discussion
# often ends somewhere else than it began. NULL if the issue can't be read;
# the triage works without it.
read_related_issue <- function(number, settings) {
  issue <- get_github_json(sprintf("/repos/%s/issues/%s", repo, number))
  if (is.null(issue)) {
    return(NULL)
  }
  limit <- settings$max_related_chars
  body <- issue$body %||% ""
  body_limit <- floor(limit / 3)
  if (nchar(body) > body_limit) {
    body <- paste0(substr(body, 1, body_limit), "\n[... rest cut]")
  }
  comments <- get_github_json_pages(sprintf("/repos/%s/issues/%s/comments", repo, number)) %||% list()
  people <- Filter(function(x) !identical(x$user$type, "Bot"), comments)
  replies <- vapply(people, function(x) sprintf("<comment>\n%s\n</comment>", x$body %||% ""), character(1))
  left <- limit - nchar(body)
  kept <- character(0)
  for (reply in rev(replies)) {
    if (nchar(reply) > left) {
      kept <- c("[... earlier comments cut]", kept)
      break
    }
    kept <- c(reply, kept)
    left <- left - nchar(reply)
  }
  state <- if (identical(issue$state, "closed")) {
    reason <- gsub("_", " ", issue$state_reason %||% "", fixed = TRUE)
    if (nzchar(reason)) sprintf("closed: %s", reason) else "closed"
  } else {
    "open"
  }
  list(
    number = as.integer(number),
    title = issue$title %||% "",
    state = state,
    text = paste(c(if (nzchar(body)) body else "(no text)", kept), collapse = "\n")
  )
}
