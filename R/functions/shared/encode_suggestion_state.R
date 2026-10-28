# The hidden comment that carries the findings in a bot PR's
# description, read back by decode_suggestion_state() on the next run.
# Base64, so no text inside can end the HTML comment early. Kept within
# `max_chars`: if the state is too long, crossed-out entries are dropped
# first (they are only shown, never compared again), oldest first.
encode_suggestion_state <- function(state, max_chars = 25000) {
  encode <- function(entries) {
    json <- jsonlite::toJSON(list(entries = entries, next_id = state$next_id), auto_unbox = TRUE, null = "null")
    sprintf("<!-- bot-suggest-state: %s -->", gsub("\n", "", jsonlite::base64_enc(charToRaw(enc2utf8(as.character(json))))))
  }
  entries <- state$entries
  out <- encode(entries)
  while (nchar(out) > max_chars) {
    crossed <- which(vapply(entries, function(e) !identical(e$status, "active"), logical(1)))
    if (length(crossed) == 0) {
      break
    }
    entries <- entries[-crossed[1]]
    out <- encode(entries)
  }
  out
}
