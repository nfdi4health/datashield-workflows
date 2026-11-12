# Notes for steps that use a variable some of their studies don't have
# (the variables file's per-variable `studies`): the analyst decides which
# studies a step runs on, so this only informs, it never drops a study.
# `code` is the step's code, `step_studies` the step's studies (empty: all
# of `servers`), `variables` the plan's merged variables, `symbol` the data
# frame's name on the servers. Wording from `texts$notes`.
check_variable_availability <- function(step_id, code, step_studies, variables, symbol, servers, texts) {
  studies <- if (length(step_studies) > 0) step_studies else servers
  pattern <- paste0("\\b", gsub(".", "\\.", symbol, fixed = TRUE), "\\$([A-Za-z.][A-Za-z0-9._]*)")
  used <- unique(sub("^.*\\$", "", regmatches(code, gregexpr(pattern, code, perl = TRUE))[[1]]))
  notes <- character(0)
  for (v in variables) {
    if (!v$name %in% used) {
      next
    }
    lacking <- studies[!vapply(studies, function(s) variable_in_study(v, s, servers), logical(1))]
    if (length(lacking) > 0) {
      notes <- c(notes, fill_template(texts$notes$variable_unavailable, list(
        STEP = step_id, VARIABLE = v$name, STUDIES = paste(sprintf("`%s`", lacking), collapse = ", "))))
    }
  }
  notes
}
