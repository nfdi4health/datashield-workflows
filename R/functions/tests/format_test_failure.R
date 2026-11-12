# The folded details of one generated test that failed for a reason in
# the test or the test environment (bad_test, env_misconfiguration): the
# test code and the failure output inside a <details> block, so the
# report shows one line per test and the code only for whoever opens it.
# The short explanation is the report line's own text.
format_test_failure <- function(test_block, failure_message) {
  paste(c(
    "<details><summary>Test and output</summary>",
    "",
    "```r", test_block, "```",
    "",
    "```", failure_message, "```",
    "",
    "</details>"
  ), collapse = "\n")
}
