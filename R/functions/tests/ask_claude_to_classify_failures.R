# Sends the failing generated tests of one function, with their failure
# output, to Claude in one call for the 3-way classification (bad_test /
# real_bug / env_misconfiguration) — a judgment made AFTER the tests
# failed, from the actual output, not guessed upfront. The function's
# source is sent once for all of them. Uses the
# "test-failure-classification" profile of config/claude.yml. Returns the
# tool call's `failures` (one entry per failure, `failure` = "F1", "F2", …
# in the order of `items`).
ask_claude_to_classify_failures <- function(claude, function_source, items) {
  listed <- vapply(seq_along(items), function(k) sprintf(
    "### F%d\n\nTest:\n```r\n%s\n```\n\nFailure output:\n```\n%s\n```", k,
    items[[k]]$block, paste(items[[k]]$message, collapse = "\n")
  ), character(1))
  prompt <- fill_template(claude$prompt, list(
    FUNCTION_SOURCE = function_source,
    FAILURES        = paste(listed, collapse = "\n\n")
  ))
  call_claude_tool(claude, build_submit_failure_classification_tool(), prompt)$failures
}
