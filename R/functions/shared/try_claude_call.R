# Runs `call()` (a function making one Claude request) and returns its
# value, or NULL if it failed even after the retries within the run: the
# failure is logged, becomes a warning annotation (warn_failed_call(), the
# job stays green) and the file is checked again in the next run while a
# bot PR is open (note_retry_file()). `label` names what was reviewed, for
# the messages; `f` is the file.
try_claude_call <- function(call, f, label = f) {
  tryCatch(call(), error = function(e) {
    message(sprintf("Claude call failed for %s: %s", label, conditionMessage(e)))
    warn_failed_call(label, f, e)
    note_retry_file(f)
    NULL
  })
}
