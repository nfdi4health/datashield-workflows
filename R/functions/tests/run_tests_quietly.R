# Runs one test file's blocks (run_test_blocks(), a separate R process
# without credentials) and returns their results; if running fails as a
# whole, logs it and returns no results. `what` describes the run for the
# message.
run_tests_quietly <- function(path, package_name, what) {
  tryCatch(run_test_blocks(path, package_name), error = function(e) {
    message(sprintf("Running %s failed: %s", what, conditionMessage(e)))
    list()
  })
}
