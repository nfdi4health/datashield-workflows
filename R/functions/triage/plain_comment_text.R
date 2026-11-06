# Text for a bot comment that came from Claude reading untrusted issue
# text: one line, at most `max_chars`, and it can do nothing but be read.
# No mentions (nobody gets notified), no links or images (nothing is
# fetched or offered to click), no markup or HTML. The zero-width space
# keeps the text readable while GitHub no longer recognises the pattern.
plain_comment_text <- function(x, max_chars) {
  x <- trimws(gsub("[[:space:]]+", " ", x))
  if (nchar(x) > max_chars) {
    x <- paste0(substr(x, 1, max_chars), "...")
  }
  x <- gsub("([\\\\`*_\\[\\]()!<>#~|])", "\\\\\\1", x, perl = TRUE)
  x <- gsub("@", "@​", x, fixed = TRUE)
  x <- gsub("://", ":​//", x, fixed = TRUE)
  gsub("www.", "www​.", x, fixed = TRUE)
}
