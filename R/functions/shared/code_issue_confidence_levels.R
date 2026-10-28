# The confidence levels of possible code bugs to report — roxygen
# (kept_code_issues()) and tests (R/suggest_tests.R): the
# code-issue-confidence input ("high", "high,medium", …) if set, else
# possible_bugs$report in config/suggestion-policy.yml (an empty list:
# none), else high and medium. "none"
# returns no levels: no possible bugs are reported (roxygen doesn't even
# ask for them) and the report has no such section.
# Stops the run on an unknown level, or "none" mixed with levels, so a
# typo fails loudly instead of silently hiding bugs.
code_issue_confidence_levels <- function(input, configured) {
  levels <- if (nzchar(trimws(input))) {
    trimws(strsplit(input, ",", fixed = TRUE)[[1]])
  } else if (!is.null(configured)) {
    # an empty list in the policy: none
    if (length(unlist(configured)) == 0) {
      return(character(0))
    }
    unlist(configured)
  } else {
    c("high", "medium")
  }
  levels <- levels[nzchar(levels)]
  if (identical(levels, "none")) {
    return(character(0))
  }
  unknown <- setdiff(levels, c("high", "medium", "low"))
  if (length(unknown) > 0 || length(levels) == 0) {
    stop(sprintf("code-issue-confidence is '%s' — use none, or high, medium and/or low, separated by commas.", input), call. = FALSE)
  }
  levels
}
