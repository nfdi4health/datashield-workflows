# Asks Claude for the steps to write (one at a time, from
# draft_steps_in_order()), writes their scripts and tests them
# (test_step_scripts()); steps that fail get up to
# `settings$repair_rounds` more rounds, each with their problems and code
# (format_repair_request()). A step's previous scripts are removed when its
# new version is written; settle_step_results() restores them if it fails.
#
# `context` is the prompt context of ask_claude_for_scripts(), plus
# `header_values` for the script headers and `repair_template`; `checks`
# holds `reference` (client_function_reference()), the plan's
# `variables` and the test `login_file`.
# Returns list(answers, candidate, outcome, notes, attempts): Claude's
# steps and the paths written per step id, the last test outcome, notes
# for the report, and the number of attempts made (a failed repair call
# doesn't count).
draft_and_test_steps <- function(to_write, plan, steps, existing, context, checks, settings, texts) {
  answers <- list()
  candidate <- list()
  notes <- character(0)
  outcome <- list(problems = list(), broken_other = character(0))
  requested <- to_write
  previous <- ""
  attempts <- 1 + settings$repair_rounds
  made <- 0

  for (round in seq_len(attempts)) {
    # A failed call in a repair round keeps what passed so far; only the
    # first call's failure ends the run.
    result <- tryCatch(ask_claude_for_scripts(context, requested, previous), error = function(e) {
      if (round == 1) {
        stop(e)
      }
      message(sprintf("Claude call in repair round %d failed: %s", round - 1, conditionMessage(e)))
      NULL
    })
    if (is.null(result)) {
      break
    }
    made <- round
    for (s in result) {
      id <- s$step_id
      answers[[id]] <- s
      unlink(c(candidate[[id]], existing$path[existing$step == id]))
      built <- assemble_step_files(Find(function(p) identical(p$id, id), plan$steps), s$sections, context$numbers[[id]],
        steps[[id]]$hash, context$header_values, s$notes, settings, texts)
      for (f in built$files) {
        writeLines(f$lines, f$path)
      }
      candidate[[id]] <- vapply(built$files, function(f) f$path, character(1))
      notes <- c(notes, built$notes)
    }
    if (length(candidate) == 0) {
      break
    }
    # Every other bot script runs too: kept steps, and requested steps that
    # have no new version (yet), so each step finds the objects it needs.
    others <- sort(existing$path[!existing$step %in% names(candidate)])
    outcome <- test_step_scripts(candidate, answers, checks$reference, checks$variables, checks$login_file, others, settings, texts, context$connections)
    if (length(outcome$problems) == 0 || round == attempts) {
      break
    }
    requested <- names(outcome$problems)
    previous <- format_repair_request(outcome$problems, answers, context$repair_template)
  }

  for (f in names(outcome$broken_other)) {
    notes <- c(notes, fill_template(texts$notes$existing_failed, list(FILE = f, ERROR = outcome$broken_other[[f]])))
  }
  list(answers = answers, candidate = candidate, outcome = outcome, notes = notes, attempts = made)
}
