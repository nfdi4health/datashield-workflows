# Claude Code's JSON result (`claude -p --output-format json`), checked:
# stops on an error result (API error, refusal, usage limit), a missing
# structured output, or output that isn't JSON. Returns the parsed result.
read_claude_code_result <- function(text) {
  result <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(result) || !is.list(result)) {
    stop(sprintf("Claude Code returned no JSON result: %s", substr(text, 1, 500)), call. = FALSE)
  }
  if (isTRUE(result$is_error) || !identical(result$subtype, "success") || is.null(result$structured_output)) {
    stop(sprintf("Claude Code ended without an answer (%s): %s", result$subtype %||% "unknown",
      substr(paste(unlist(result$result %||% result$errors %||% ""), collapse = " "), 1, 500)), call. = FALSE)
  }
  result
}
