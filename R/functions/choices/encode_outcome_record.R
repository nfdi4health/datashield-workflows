# The hidden comment holding a closed bot PR's outcome record, base64
# like the state (encode_suggestion_state()), so no text inside can end
# the HTML comment. Kept within `max_chars`: edit texts are dropped first,
# then review comments.
encode_outcome_record <- function(record, max_chars = 20000) {
  encode <- function(r) {
    json <- jsonlite::toJSON(r, auto_unbox = TRUE, null = "null", na = "null")
    sprintf("<!-- bot-suggest-outcome: %s -->", gsub("\n", "", jsonlite::base64_enc(charToRaw(enc2utf8(as.character(json))))))
  }
  out <- encode(record)
  if (nchar(out) > max_chars) {
    record$findings <- lapply(record$findings, function(f) { f$proposed <- NULL; f$final <- NULL; f })
    record$texts_dropped <- TRUE
    out <- encode(record)
  }
  if (nchar(out) > max_chars) {
    record$comments <- NULL
    record$comments_dropped <- TRUE
    out <- encode(record)
  }
  out
}
