# Reads the analyst's plan file (YAML) and checks its fixed core with
# validate_analysis_plan(). Stops with every problem at once (wording from
# `texts$plan`), before any package install or Claude call, so the analyst
# can fix the file in one go. Fills in defaults: symbol "D" (as in the
# dsAnalysis login templates), a step id from the title where none is
# given, and each variable's `kind` (continuous / integer / categorical)
# from its type via `variable_types` (settings: type names -> kind).
# With `variables_file` (settings paths$variables, dsAnalysis's
# initVariables()), its variables come first and the plan's own entries
# are merged on top (merge_variables_file()); file entries that wouldn't
# pass the check are left out and listed in `variables_left_out`.
read_analysis_plan <- function(path, variable_types, texts, variables_file = "") {
  fail <- function(key, ...) stop(fill_template(texts$plan[[key]], list(PATH = path, ...)), call. = FALSE)
  if (!file.exists(path)) {
    fail("not_found")
  }
  plan <- tryCatch(yaml::read_yaml(path), error = function(e) fail("not_yaml", ERROR = conditionMessage(e)))
  if (!is.list(plan)) {
    fail("not_mapping")
  }

  if (is.null(plan$symbol)) {
    plan$symbol <- "D"
  }
  plan$steps <- lapply(plan$steps, function(s) {
    if (is.list(s) && is.null(s$id) && is.character(s$title)) {
      s$id <- step_id_from_title(s$title)
    }
    s
  })
  plan$variables <- lapply(plan$variables, function(v) {
    if (is.list(v) && is.character(v$type) && !is.null(variable_types[[v$type]])) {
      v$kind <- variable_types[[v$type]]
    }
    v
  })

  # The generated variables file, with the plan's own entries on top.
  plan$variables_left_out <- character(0)
  if (nzchar(variables_file)) {
    check <- function(v) check_plan_variable(v, fill_template(texts$plan$label_variable, list(NAME = v$name)), names(variable_types), texts)
    merged <- merge_variables_file(variables_file, plan$variables, variable_types, check)
    plan$variables <- merged$variables
    plan$variables_left_out <- merged$left_out
    plan$variables_from_file <- merged$from_file
  }

  problems <- validate_analysis_plan(plan, names(variable_types), texts)
  if (length(problems) > 0) {
    stop(paste(c(fill_template(texts$plan$problems, list(PATH = path, COUNT = length(problems))), paste("-", problems)), collapse = "\n"), call. = FALSE)
  }
  plan
}
