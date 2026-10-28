# The files testthat sources automatically before the tests — setup*.R and
# helper*.R in tests/testthat/ — where packages keep logins, fixtures and
# helper functions. Returns their paths.
test_support_files <- function() {
  dir <- file.path("tests", "testthat")
  if (!dir.exists(dir)) {
    return(character(0))
  }
  sort(list.files(dir, pattern = "^(setup|helper).*\\.[Rr]$", full.names = TRUE))
}
