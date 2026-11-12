# Checks the new scripts: every DataSHIELD call against the installed
# clients (check_ds_calls()) and every "object$column" string against the
# plan's variables (check_column_references()), calls that only look at
# something (check_inspection_calls()), then a test run of all
# scripts in file order (run_analysis_scripts()): the new ones
# (`candidate`, step id -> paths) together with `other_files`, the
# project's other bot scripts, so each step runs with the objects of the
# steps before it. `settings` gives the test profile and timeout, `texts`
# the wording of the problems.
# Returns list(problems, broken_other, objects): problems per step id with any
# (only failing steps), errors of other_files (named by path), and what is
# on the servers afterwards (run_analysis_scripts(); `connections` names
# the connections object).
# Stops if the DSLite setup itself fails: then nothing can be judged.
test_step_scripts <- function(candidate, answers, reference, variables, login_file, other_files, settings, texts, connections = NULL) {
  ids <- names(candidate)
  all_code <- paste(c(vapply(answers[ids], step_code, character(1)), unlist(lapply(other_files, readLines, warn = FALSE))), collapse = "\n")
  problems <- lapply(setNames(ids, ids), function(id) {
    code <- step_code(answers[[id]])
    c(check_ds_calls(code, reference, texts), check_column_references(code, all_code, variables, texts),
      check_inspection_calls(code, unlist(settings$inspection_functions), texts))
  })

  run <- run_analysis_scripts(login_file, sort(c(other_files, unlist(candidate, use.names = FALSE))),
    settings$profiles$testing, settings$test_run_timeout_seconds, connections)
  if (!is.na(run$login_error)) {
    stop(sprintf("The DSLite test setup (%s) failed: %s", login_file, run$login_error), call. = FALSE)
  }
  # A run stopped for taking too long can't say which script hung, so
  # every new script counts as failing (the analyst's own aren't blamed).
  if (isTRUE(run$timed_out)) {
    for (id in ids) {
      problems[[id]] <- c(problems[[id]], fill_template(texts$checks$timeout, list(SECONDS = settings$test_run_timeout_seconds)))
    }
  }
  for (id in ids) {
    runtime <- run$errors[candidate[[id]]]
    runtime <- runtime[!is.na(runtime)]
    if (length(runtime) > 0) {
      problems[[id]] <- c(problems[[id]], fill_template(texts$checks$runtime_error, list(FILE = names(runtime)[1], ERROR = runtime[[1]])))
    }
  }
  broken <- run$errors[other_files]
  list(problems = Filter(length, problems), broken_other = broken[!is.na(broken)], objects = run$objects %||% "")
}
