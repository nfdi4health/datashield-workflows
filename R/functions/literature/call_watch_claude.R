# One Claude call of the literature watch's later steps (vocabulary,
# "Exists?"): list(answer = the tool's input or NULL, limit = TRUE at the
# subscription's usage limit, when the run's further calls would fail the
# same way). Other failures are logged and leave the answer NULL; the
# items are asked again in the next run.
call_watch_claude <- function(claude, tool, prompt, label) {
  limit <- FALSE
  answer <- tryCatch(call_claude_tool(claude, tool, prompt), error = function(e) {
    if (is_usage_limit(conditionMessage(e))) {
      limit <<- TRUE
      message(sprintf("The subscription's usage limit was reached (%s): %s", label, conditionMessage(e)))
    } else {
      message(sprintf("The call for %s failed; asked again next run: %s", label, conditionMessage(e)))
    }
    NULL
  })
  list(answer = answer, limit = limit)
}
