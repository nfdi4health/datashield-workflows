# Writes a test file's content — or, with content NULL, puts it back
# exactly as found (removing it if it didn't exist before), which is how
# rejected candidates are backed out after a run. Returns the path when
# the file now differs from the original, else NULL.
write_test_file <- function(existing_test_file, content) {
  path <- existing_test_file$path

  if (is.null(content) || (!existing_test_file$exists && !nzchar(trimws(content)))) {
    if (existing_test_file$exists) {
      writeLines(existing_test_file$content, path)
    } else if (file.exists(path)) {
      file.remove(path)
    }
    return(invisible(NULL))
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(content, path)
  if (existing_test_file$exists && identical(content, existing_test_file$content)) {
    return(invisible(NULL))
  }
  path
}
