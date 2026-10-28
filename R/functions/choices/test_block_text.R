# The text of the test_that() block named `description` in a test file's
# content (parse_test_file()), or NULL if the file has no such block.
test_block_text <- function(content, description) {
  if (is.null(content) || !nzchar(content)) {
    return(NULL)
  }
  block <- Find(function(b) identical(b$description, description), parse_test_file(content))
  if (is.null(block)) {
    return(NULL)
  }
  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]
  paste(lines[block$first_line:block$last_line], collapse = "\n")
}
