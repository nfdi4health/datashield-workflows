# What happened on an issue up to now, from its comments: the category and
# text of the last triage, and every comment people wrote, oldest first
# (bots left out). All of them, also those before the last triage: that
# triage's text is only a summary, and a repeat has to read the conversation
# itself, or it loses what was already said.
# Only github-actions[bot]'s comments count as a triage, as in the gate:
# anyone can copy the marker.
triage_history <- function(comments) {
  is_bot <- function(x) identical(x$user$type, "Bot")
  marker <- "^<!-- bot-triage: ([a-z-]+) -->"
  is_triage <- function(x) identical(x$user$login, "github-actions[bot]") && grepl(marker, x$body %||% "")
  at <- which(vapply(comments, is_triage, logical(1)))
  last <- if (length(at) > 0) max(at) else 0L

  people <- Filter(function(x) !is_bot(x), comments)
  list(
    category = if (last > 0) sub(paste0(marker, ".*"), "\\1", comments[[last]]$body) else NULL,
    comment = if (last > 0) comments[[last]]$body else NULL,
    replies = lapply(people, function(x) list(author = x$user$login %||% "", body = x$body %||% ""))
  )
}
