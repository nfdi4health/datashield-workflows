# Test files verbatim for the prompt, each under its file name (Claude
# names the file in its decisions on existing tests). Each file can be capped
# at `max_chars` (examples are; a function's own tests are shown whole),
# and the cut is stated. `empty` is returned when there
# are no files.
format_test_files <- function(files, empty, max_chars = Inf) {
  if (length(files) == 0) {
    return(empty)
  }
  parts <- vapply(files, function(f) {
    content <- f$content
    if (nchar(content) > max_chars) {
      content <- paste0(substr(content, 1, max_chars), "\n# … (file continues, cut here)")
    }
    sprintf("File `%s`:\n```r\n%s\n```", basename(f$path), content)
  }, character(1))
  paste(parts, collapse = "\n\n")
}
