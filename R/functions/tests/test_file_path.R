# Where an R file's tests live: tests/testthat/test-<name>.R, or
# test-<category>-<name>.R in a categorised repository
# (detect_test_scheme()). `name` is the R file's name without .R
# (test_file_name()), not the function's: R/initMockData.R has its tests in
# test-initMockData.R, also when the function is called initMockdata(). The
# other workflows pair R files and tests the same way.
test_file_path <- function(name, category = NA_character_) {
  file <- if (is.na(category)) {
    sprintf("test-%s.R", name)
  } else {
    sprintf("test-%s-%s.R", category, name)
  }
  file.path("tests", "testthat", file)
}
