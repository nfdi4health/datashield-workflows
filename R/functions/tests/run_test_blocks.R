# Actually runs the just-written test file via testthat and reports
# pass/fail per test_that() block, matched by description — the "every
# generated test must actually be run before being trusted" step. The
# package under test is loaded from source first (testthat -> pkgload);
# without that, every test fails in a fresh CI process with "could not
# find function". Returns a list of list(description, passed, message) —
# message is NA for passing tests, the failure/error text otherwise.
#
# The tests are generated code, so they run in a separate R process
# without the Claude and GitHub tokens (credential_variables()), like the
# analysis bot's scripts. That also keeps their global assignments and
# loaded packages out of the bot's own session.
run_test_blocks <- function(path, package_name) {
  child <- function(path, package_name) {
    raw <- testthat::test_file(path, reporter = "list", package = package_name, load_package = "source")
    lapply(raw, function(item) {
      failure <- Filter(
        function(r) inherits(r, "expectation_failure") || inherits(r, "expectation_error"),
        item$results
      )
      passed <- length(failure) == 0
      message <- if (passed) {
        NA_character_
      } else {
        conditionMessage(failure[[1]])
      }
      list(description = item$test, passed = passed, message = message)
    })
  }
  env <- callr::rcmd_safe_env()
  env[credential_variables()] <- ""
  callr::r(child, args = list(path = path, package_name = package_name), env = env)
}
