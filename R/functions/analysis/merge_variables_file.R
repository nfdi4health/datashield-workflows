# The variables of the project's variables file (`path`, settings
# paths$variables, written by dsAnalysis's initVariables()) with the plan's
# own `variables:` on top: an entry of the plan replaces the file's fields
# of the same name, field by field (e.g. only `role`, or a corrected
# range); plan entries the file doesn't have are added. File entries that
# would fail the plan check (`check`, a function of one entry returning its
# problems) are left out, not fatal: the file is generated, and e.g. a
# variable with one category or no range (disclosure control) shouldn't
# stop the run. `kind` is derived from the type as read_analysis_plan()
# does (`variable_types`). Returns list(variables, left_out, from_file):
# the merged list, the names left out, and whether a file was read.
merge_variables_file <- function(path, plan_variables, variable_types, check) {
  if (!file.exists(path)) {
    return(list(variables = plan_variables, left_out = character(0), from_file = FALSE))
  }
  from_file <- yaml::read_yaml(path)$variables
  name_of <- function(v) if (is.list(v) && is.character(v$name)) v$name else NA_character_
  plan_names <- vapply(plan_variables, name_of, character(1))

  merged <- list()
  left_out <- character(0)
  for (v in from_file) {
    name <- name_of(v)
    own <- plan_variables[which(plan_names == name)]
    if (length(own) > 0) {
      v[names(own[[1]])] <- own[[1]]
    }
    if (is.character(v$type) && !is.null(variable_types[[v$type]])) {
      v$kind <- variable_types[[v$type]]
    }
    if (length(own) == 0 && length(check(v)) > 0) {
      left_out <- c(left_out, name)
      next
    }
    merged[[length(merged) + 1]] <- v
  }
  file_names <- vapply(from_file, name_of, character(1))
  extra <- plan_variables[is.na(plan_names) | !plan_names %in% file_names]
  list(variables = c(merged, extra), left_out = left_out[!is.na(left_out)], from_file = TRUE)
}
