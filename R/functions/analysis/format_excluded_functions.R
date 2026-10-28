# The functions Claude must not use (`excluded`: excluded_functions of
# config/analysis-suggest.yml, function name -> reason) as one line for
# the prompt, e.g. "`ds.glmSLMA` (study-level meta-analysis isn't
# available …)". A name a project set to null (`name: ~`) is gone after
# the merge already.
format_excluded_functions <- function(excluded) {
  excluded <- Filter(Negate(is.null), excluded)
  if (length(excluded) == 0) {
    return("(none)")
  }
  paste(sprintf("`%s` (%s)", names(excluded), unlist(excluded)), collapse = "; ")
}
