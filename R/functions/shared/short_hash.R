# A short, stable hash of an R object or text (first 10 hex characters of
# its MD5): enough to tell versions of a prompt or config apart.
short_hash <- function(x) {
  text <- if (is.character(x)) paste(x, collapse = "\n") else paste(deparse(x), collapse = "\n")
  file <- tempfile()
  on.exit(unlink(file))
  writeChar(text, file, eos = NULL, useBytes = TRUE)
  substr(unname(tools::md5sum(file)), 1, 10)
}
