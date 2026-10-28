# The reasons that lead to a proposed change (roxygen: accepted_roxygen_fields(),
# tests: filter_generated_tests()): the accept-reasons input
# ("missing,inaccurate,incomplete,clarity", …) if set, else the reasons
# with `accept: true` in config/suggestion-policy.yml. Stops the run on a reason the task
# doesn't know (suggestion_reasons()), so a typo fails loudly instead of
# silently dropping every suggestion. See
# dev-notes/suggestion-thresholds.md.
accepted_reasons <- function(input, configured, task) {
  reasons <- if (nzchar(trimws(input))) {
    trimws(strsplit(input, ",", fixed = TRUE)[[1]])
  } else {
    unlist(configured)
  }
  reasons <- reasons[nzchar(reasons)]
  known <- suggestion_reasons(task)
  if (length(reasons) == 0 || length(setdiff(reasons, known)) > 0) {
    given <- paste(reasons, collapse = ",")
    if (nzchar(trimws(input))) {
      given <- input
    }
    stop(sprintf("accept-reasons is '%s' — use one or more of: %s, separated by commas.",
                 given, paste(known, collapse = ", ")), call. = FALSE)
  }
  reasons
}
