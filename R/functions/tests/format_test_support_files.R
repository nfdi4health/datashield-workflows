# Files verbatim for the prompt — the test support files and the files
# they source (test_sourced_files()), so Claude uses the objects, symbols,
# connection helpers and helper functions the package actually defines
# instead of guessing them. Each file is capped at 20000 characters, all
# files together at 60000; a cut, and files left out for the total, are
# stated.
format_test_support_files <- function(paths) {
  if (length(paths) == 0) {
    return("(none)")
  }
  budget <- 60000
  parts <- character(0)
  left_out <- character(0)
  for (path in paths) {
    content <- paste(readLines(path, warn = FALSE), collapse = "\n")
    if (nchar(content) > 20000) {
      content <- paste0(substr(content, 1, 20000), "\n# … (file continues, cut here)")
    }
    if (nchar(content) > budget) {
      left_out <- c(left_out, path)
      next
    }
    budget <- budget - nchar(content)
    parts <- c(parts, sprintf("File `%s`:\n```r\n%s\n```", path, content))
  }
  if (length(left_out) > 0) {
    parts <- c(parts, sprintf("Not shown (too long in total): %s", paste0("`", left_out, "`", collapse = ", ")))
  }
  paste(parts, collapse = "\n\n")
}
