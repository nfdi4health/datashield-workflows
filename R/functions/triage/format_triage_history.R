# The prompt's part on what came before: the last verdict, the issue it
# called this a duplicate of, and people's comments, oldest first, cut to
# settings$max_body_chars and settings$max_reply_chars, which bounds what
# one issue can cost. Empty on a first triage without comments.
format_triage_history <- function(issue, settings) {
  replies <- ""
  if (length(issue$replies) > 0) {
    who <- function(x) if (identical(x$author, issue$author)) "the issue's author" else "someone else"
    replies <- paste(vapply(issue$replies, function(x) {
      sprintf("<comment by=\"%s\">\n%s\n</comment>", who(x), x$body)
    }, character(1)), collapse = "\n")
    # The newest comments matter most: an answer or objection is at the end.
    if (nchar(replies) > settings$max_reply_chars) {
      start <- nchar(replies) - settings$max_reply_chars + 1
      replies <- paste0("[... earlier comments cut]\n", substr(replies, start, nchar(replies)))
    }
  }
  if (is.null(issue$previous_category) && !nzchar(replies)) {
    return("")
  }
  parts <- character(0)
  if (!is.null(issue$previous_category)) {
    parts <- c(parts, sprintf(
      "You triaged this issue before as `%s`. Your comment:\n\n<previous_triage>\n%s\n</previous_triage>",
      issue$previous_category, issue$previous_comment
    ))
  }
  if (!is.null(issue$disputed)) {
    parts <- c(parts, sprintf(
      "The issue you called this a duplicate of, with its discussion:\n\n<duplicate_of number=\"%d\" state=\"%s\">\n%s\n\n%s\n</duplicate_of>",
      issue$disputed$number, issue$disputed$state, issue$disputed$title, issue$disputed$text
    ))
  }
  if (nzchar(replies)) {
    parts <- c(parts, sprintf("The comments people wrote on this issue, oldest first:\n\n%s", replies))
  }
  paste(c(parts, ""), collapse = "\n\n")
}
