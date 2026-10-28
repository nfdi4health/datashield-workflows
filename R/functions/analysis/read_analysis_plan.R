# Reads the analyst's plan file (YAML) and checks its fixed core with
# validate_analysis_plan(). Stops with every problem at once (wording from
# `texts$plan`), before any package install or Claude call, so the analyst
# can fix the file in one go. Fills in defaults: symbol "D" (as in the
# dsAnalysis login templates), a step id from the title where none is
# given, and each variable's `kind` (continuous / integer / categorical)
# from its type via `variable_types` (settings: type names -> kind).
read_analysis_plan <- function(path, variable_types, texts) {
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

  problems <- validate_analysis_plan(plan, names(variable_types), texts)
  if (length(problems) > 0) {
    stop(paste(c(fill_template(texts$plan$problems, list(PATH = path, COUNT = length(problems))), paste("-", problems)), collapse = "\n"), call. = FALSE)
  }
  plan
}
