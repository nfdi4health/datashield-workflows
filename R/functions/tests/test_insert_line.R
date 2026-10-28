# Where new tests go in an existing test file: the line after which they
# are inserted, or NULL to append at the end. Files that clean up at the
# end — dsBaseClient's `test_that("shutdown", …)` followed by a top-level
# disconnect — must get new tests before that, or they run without a
# connection. So new tests go after the last test_that() block that is
# not a clean-up block (shutdown, teardown, cleanup, disconnect, done)
# whenever a clean-up block or other code follows it; otherwise at the
# end. `blocks` comes from parse_test_file().
test_insert_line <- function(content, blocks) {
  if (length(blocks) == 0) {
    return(NULL)
  }
  cleanup <- grepl("^\\s*(shut\\s*down|tear\\s*down|clean\\s*up|disconnect|done)\\s*$", vapply(blocks, function(b) b$description, character(1)), ignore.case = TRUE)
  if (all(cleanup)) {
    return(NULL)
  }
  last <- blocks[[max(which(!cleanup))]]

  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]
  after <- lines[seq_len(length(lines)) > last$last_line]
  code_after <- any(nzchar(trimws(after)) & !grepl("^\\s*#", after))
  if (code_after) {
    last$last_line
  } else {
    NULL
  }
}
