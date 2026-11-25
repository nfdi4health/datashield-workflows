# Installs the package under test into a library of its own, so its tests
# run as under R CMD check: against the installed package, not loaded from
# source with pkgload (which hides some failures, dsAnalysis #38/#41). Sets
# BOT_TEST_LIB for run_test_blocks(). The test bot changes no code in R/,
# so one install per run is enough. If the install fails, the tests run
# from source as before, with a message. Returns the library path or "".
install_package_for_tests <- function(dir = ".") {
  lib <- file.path(tempdir(), "bot-test-lib")
  dir.create(lib, showWarnings = FALSE, recursive = TRUE)
  out <- tryCatch(
    suppressWarnings(system2(file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", "--no-docs", "--no-multiarch", "--no-test-load", "-l", shQuote(lib), shQuote(normalizePath(dir))),
      stdout = TRUE, stderr = TRUE)),
    error = function(e) structure(conditionMessage(e), status = 1L))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    message("Installing the package for the test runs failed; the tests run from source instead:\n",
      paste(utils::tail(out, 15), collapse = "\n"))
    Sys.unsetenv("BOT_TEST_LIB")
    return("")
  }
  Sys.setenv(BOT_TEST_LIB = lib)
  message(sprintf("The tests run against the package installed in %s, as under R CMD check.", lib))
  lib
}
