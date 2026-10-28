# Writes the requested steps one at a time, in plan order: each with
# draft_and_test_steps() (Claude, checks, test run, repair rounds), and
# only once the steps it depends on (step_dependencies(), the plan's
# `depends_on`, else all earlier steps) haven't failed in this run — a
# step built on a broken one would only fail as a consequence. Each step's
# prompt shows the scripts that run before it (kept ones and those written
# in this run) and what the passing steps left on the servers (objects,
# classes, columns from the last test run).
#
# A step that still fails is taken out at once: its new scripts are
# removed and its previous version restored (`rewritten`, `old_content`),
# so the following test runs don't run broken code. A step with notes
# only ("not possible") blocks nothing. A Claude call that fails counts as
# no answer for that step, the others go on.
#
# Returns what settle_step_results() needs: list(answers, candidate,
# outcome = list(problems, broken_other), notes, attempts (per step id),
# blocked (step id -> the failed steps it waits for)).
draft_steps_in_order <- function(to_write, plan, steps, existing, context, checks, settings, texts, rewritten, old_content) {
  deps <- step_dependencies(plan)
  order <- intersect(names(deps), to_write)
  out <- list(answers = list(), candidate = list(), outcome = list(problems = list(), broken_other = character(0)),
              notes = character(0), attempts = integer(0), blocked = list())
  failed <- character(0)
  present <- existing[, c("path", "step")]
  context$all_step_ids <- order  # one tool schema for the whole run, so the prompt cache holds
  context$created_objects <- "(none known yet: no step has run in this run)"

  for (i in seq_along(order)) {
    id <- order[i]
    waits_for <- intersect(deps[[id]], c(failed, names(out$blocked)))
    if (length(waits_for) > 0) {
      message(sprintf("Step %s waits for %s, which failed; not written.", id, paste(waits_for, collapse = ", ")))
      out$blocked[[id]] <- waits_for
      next
    }
    pending <- order[seq_along(order) > i]
    context$existing_steps <- format_existing_steps(sort(present$path[!present$step %in% c(id, pending)]))

    d <- tryCatch(draft_and_test_steps(id, plan, steps, present, context, checks, settings, texts), error = function(e) {
      message(sprintf("Claude call for step %s failed: %s", id, conditionMessage(e)))
      NULL
    })
    if (!is.null(d)) {
      out$answers[[id]] <- d$answers[[id]]
      out$candidate[[id]] <- d$candidate[[id]]
      out$notes <- c(out$notes, d$notes)
      out$attempts[[id]] <- d$attempts
      out$outcome$broken_other <- d$outcome$broken_other
    }

    if (is.null(d) || is.null(d$answers[[id]]) || id %in% names(d$outcome$problems)) {
      failed <- c(failed, id)
      if (!is.null(d)) {
        out$outcome$problems[[id]] <- d$outcome$problems[[id]]
      }
      # Shown in the job log before the scripts are removed.
      for (f in out$candidate[[id]][file.exists(out$candidate[[id]])]) {
        cat(sprintf("::group::Failed script %s (step %s)\n", f, id))
        cat(readLines(f, warn = FALSE), sep = "\n")
        cat("\n::endgroup::\n")
      }
      unlink(out$candidate[[id]])
      for (p in rewritten$path[rewritten$step == id]) {
        writeLines(old_content[[p]], p)
      }
      next
    }
    present <- rbind(present[present$step != id, ], data.frame(path = out$candidate[[id]], step = rep(id, length(out$candidate[[id]]))))
    if (nzchar(d$outcome$objects %||% "")) {
      context$created_objects <- d$outcome$objects
    }
  }
  out
}
