# Keeps only the possible code bugs Claude concluded are real defects
# (verdict "defect") with a confidence in `confidences`
# (possible_bugs.report in config/suggestion-policy.yml; default high and medium).
# Everything dropped is logged with its reason, so a wrongly dropped bug
# can still be found in the job log.
kept_code_issues <- function(issues, confidences, path) {
  # "none": not asked for
  if (length(confidences) == 0) {
    return(list())
  }
  Filter(function(i) {
    if (!identical(i$verdict, "defect")) {
      message(sprintf("%s: dropping possible bug '%s' — verdict '%s'.", path, i$summary, i$verdict))
      return(FALSE)
    }
    if (!isTRUE(i$confidence %in% confidences)) {
      message(sprintf("%s: dropping possible bug '%s' — confidence '%s'.", path, i$summary, i$confidence))
      return(FALSE)
    }
    TRUE
  }, issues)
}
