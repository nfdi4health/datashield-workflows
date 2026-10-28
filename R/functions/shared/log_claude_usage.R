# One log line per Claude call with its token usage, e.g.
# "Claude usage (submit_tests, claude-opus-5): input 1830, cache write
# 14210, cache read 0, output 2410 (thinking 980)". The four input/output
# kinds are billed at different rates (cache reads at a tenth of input on
# most models), so this is what a run's cost can be read from — and how to
# see whether the prompt cache hits (cache read > 0 from the second call
# on). Never fails the call.
log_claude_usage <- function(config, usage) {
  if (is.null(usage)) {
    return(invisible(NULL))
  }
  n <- function(x) {
    x %||% 0
  }
  thinking <- usage$output_tokens_details$thinking_tokens
  thinking_note <- ""
  if (!is.null(thinking)) {
    thinking_note <- sprintf(" (thinking %d)", thinking)
  }
  message(sprintf(
    "Claude usage (%s, %s): input %d, cache write %d, cache read %d, output %d%s",
    config$tool_name, config$model,
    n(usage$input_tokens), n(usage$cache_creation_input_tokens), n(usage$cache_read_input_tokens), n(usage$output_tokens),
    thinking_note
  ))
  invisible(NULL)
}
