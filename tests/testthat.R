# Runs the unit tests of R/functions/ (this repository isn't an R package):
#   Rscript tests/testthat.R
# from the repository root. Needs testthat, withr, httr2, jsonlite, yaml,
# purrr, desc, callr.
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)
