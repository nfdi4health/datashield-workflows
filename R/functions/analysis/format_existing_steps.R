# The project's other bot scripts as prompt text, so Claude reuses their
# objects instead of repeating their work: each file's path and content.
format_existing_steps <- function(files) {
  if (length(files) == 0) {
    return("(none yet)")
  }
  paste(vapply(files, function(f) {
    sprintf("File %s:\n```r\n%s\n```", f, paste(readLines(f, warn = FALSE), collapse = "\n"))
  }, character(1)), collapse = "\n\n")
}
