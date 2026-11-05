# A rule's `name` from config/ds-argument-rules.yml: a decided name, or a
# list of candidates while still open (the first is the front-runner).
# Returns the name to propose and whether the rule is still open — open
# ones are proposed all the same, marked in the entry and the report.
rule_name <- function(value) {
  values <- unlist(value)
  list(name = values[1], open = length(values) > 1)
}
