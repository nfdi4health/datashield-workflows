# Content of a test file that doesn't exist yet: the new test_that()
# blocks, framed by Claude's top-level `file_setup_code` /
# `file_teardown_code` where the package's test files connect and
# disconnect outside test_that() (dsBaseClient's
# connect.studies.dataset.cnsim() … disconnect.studies.dataset.cnsim());
# both are empty for most packages. Sanitized like assemble_test_block().
new_test_file_content <- function(test_blocks, result, function_name) {
  clean <- function(field) {
    text <- if (is.null(result[[field]])) {
      ""
    } else {
      result[[field]]
    }
    trimws(strip_artifact_lines(text, "^\\s*```", "markdown code fences", field, function_name))
  }
  parts <- c(clean("file_setup_code"), test_blocks, clean("file_teardown_code"))
  paste(parts[nzchar(parts)], collapse = "\n\n")
}
