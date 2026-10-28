# Structure of the test data the package's setup/helper files create, for
# the prompt — so Claude can assert concrete values (row counts, factor
# levels) instead of guessing. Runs collect_test_data() in a separate R
# process (see there); never fails the run, it reports why instead.
summarize_test_data <- function(files, functions_dir) {
  if (length(files) == 0) {
    return("(no setup or helper files)")
  }

  out <- tempfile(fileext = ".txt")
  driver <- tempfile(fileext = ".R")
  writeLines(c(
    sprintf("source(%s)", deparse(normalizePath(file.path(functions_dir, "collect_test_data.R")))),
    sprintf("collect_test_data(%s, %s)", paste(deparse(files), collapse = ""), deparse(out))
  ), driver)
  # The package's setup code runs there: no Claude or GitHub tokens.
  system2(file.path(R.home("bin"), "Rscript"), shQuote(driver), stdout = FALSE, stderr = FALSE, timeout = 300,
          env = paste0(credential_variables(), "="))

  if (!file.exists(out)) {
    return("(could not be determined: running the setup files failed)")
  }
  paste(readLines(out, warn = FALSE), collapse = "\n")
}
