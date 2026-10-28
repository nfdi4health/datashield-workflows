# The existing tests' results before any change, for the prompt: per test
# file, one line per test_that() block, passed or FAILED with the error
# (trimmed to 1000 characters). `results` is a named list, test file path
# -> run_test_blocks() results.
format_test_results <- function(results) {
  if (length(results) == 0) {
    return("(no existing tests)")
  }
  per_file <- vapply(names(results), function(path) {
    lines <- vapply(results[[path]], function(r) {
      if (isTRUE(r$passed)) {
        return(sprintf("- \"%s\": passed", r$description))
      }
      msg <- gsub("\\s+", " ", r$message)
      if (nchar(msg) > 1000) {
        msg <- paste0(substr(msg, 1, 1000), " …")
      }
      sprintf("- \"%s\": FAILED — %s", r$description, msg)
    }, character(1))
    if (length(lines) == 0) {
      lines <- "- (no results: the file did not run)"
    }
    paste(c(sprintf("File `%s`:", basename(path)), lines), collapse = "\n")
  }, character(1))
  paste(per_file, collapse = "\n\n")
}
