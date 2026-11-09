# The documentation of the functions the issue is about, for the triage
# prompt (read_function_documentation()). "(none)" when the shortlist named
# no function or none could be read.
format_documentation <- function(docs) {
  docs <- Filter(Negate(is.null), docs)
  if (length(docs) == 0) {
    return("(none)")
  }
  paste(vapply(docs, function(x) {
    text <- if (x$documented) x$text else "(this function has no roxygen documentation)"
    sprintf("<documentation file=\"%s\" function=\"%s\">\n%s\n\n%s\n</documentation>", x$file, x$name, x$usage, text)
  }, character(1)), collapse = "\n\n")
}
