# Reads Claude Code's JSON result (`claude -p --output-format json`) and
# returns the structured answer (the tool schema's object), or stops with
# what went wrong: an error result (API error, refusal, usage limit), no
# valid structured output, or output that isn't JSON at all.
read_agent_result <- function(text) {
  result <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(result) || !is.list(result)) {
    stop(sprintf("Claude Code returned no JSON result: %s", substr(text, 1, 500)), call. = FALSE)
  }
  if (isTRUE(result$is_error) || !identical(result$subtype, "success") || is.null(result$structured_output)) {
    stop(sprintf("Claude Code ended without an answer (%s): %s", result$subtype %||% "unknown",
      substr(paste(unlist(result$result %||% result$errors %||% ""), collapse = " "), 1, 500)), call. = FALSE)
  }
  if (!is.null(result$usage)) {
    message(sprintf("Agent usage: %s turns, input %s, output %s tokens%s", result$num_turns %||% "?",
      result$usage$input_tokens %||% "?", result$usage$output_tokens %||% "?",
      if (!is.null(result$total_cost_usd)) sprintf(", about %.2f USD (estimate)", result$total_cost_usd) else ""))
  }
  result$structured_output
}
