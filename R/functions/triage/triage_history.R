# What happened on an issue up to now, from its comments: the category and
# text of the last triage, and the comments people wrote after it (bots
# left out). Before a first triage: all people's comments, and no category.
# Only github-actions[bot]'s comments count as a triage, as in the gate:
# anyone can copy the marker.
triage_history <- function(comments) {
  is_bot <- function(x) identical(x$user$type, "Bot")
  marker <- "^<!-- bot-triage: ([a-z-]+) -->"
  is_triage <- function(x) identical(x$user$login, "github-actions[bot]") && grepl(marker, x$body %||% "")
  at <- which(vapply(comments, is_triage, logical(1)))
  last <- if (length(at) > 0) max(at) else 0L

  later <- if (last < length(comments)) comments[seq(last + 1, length(comments))] else list()
  later <- Filter(function(x) !is_bot(x), later)
  list(
    category = if (last > 0) sub(paste0(marker, ".*"), "\\1", comments[[last]]$body) else NULL,
    comment = if (last > 0) comments[[last]]$body else NULL,
    replies = lapply(later, function(x) list(author = x$user$login %||% "", body = x$body %||% ""))
  )
}
