# The reasons Claude chooses from per task ("roxygen", "tests"), from
# config/suggestion-policy.yml: their names (the tool schema's enum), with
# `meanings` TRUE a named vector of what each means (for the schema's
# description and the prompt), with `accepted` TRUE only those that lead
# to a proposed change by default (`accept: true`; the accept-reasons
# input overrides it, accepted_reasons()). See
# dev-notes/suggestion-thresholds.md.
suggestion_reasons <- function(task, meanings = FALSE, accepted = FALSE, policy = suggestion_policy()) {
  reasons <- policy[[task]]$reasons
  if (is.null(reasons) || length(reasons) == 0) {
    stop(sprintf("Unknown suggestion task '%s'.", task))
  }
  if (accepted) {
    reasons <- Filter(function(r) isTRUE(r$accept), reasons)
  }
  if (meanings) {
    return(vapply(reasons, function(r) r$meaning, character(1)))
  }
  names(reasons)
}
