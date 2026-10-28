# Lazily creates a DSLite test setup once per package when a client-side
# function needs DSLite and decide_dslite_setup() decided to create one
# (dslite-setup input). Writes tests/testthat/setup.R if there is none
# (fewest files, the usual convention); if a setup.R exists without
# DSLite (e.g. other fixtures), writes setup-dslite.R instead, so that
# file is never touched — testthat runs every setup*.R (a name must start
# with "setup"). Revisable, see dev-notes/test-suggest.md. Safe to
# call once per processed function: after the first write,
# detect_connection_approaches() finds DSLite and this isn't called again.
ensure_dslite_setup_file <- function(dataset_choice, package_name) {
  dir <- file.path("tests", "testthat")
  path <- file.path(dir, "setup.R")
  if (file.exists(path)) {
    path <- file.path(dir, "setup-dslite.R")
  }
  if (file.exists(path)) {
    return(invisible(NULL))
  }

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  snippet <- build_dslite_test_snippet(dataset_choice, package_name)
  writeLines(snippet, path)
  invisible(path)
}
