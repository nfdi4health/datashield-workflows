# When a job runs, in words, in two parts: `needs` — the result of the
# jobs it waits for ("if check fails" for `needs.check.result ==
# 'failure'`), "" if it doesn't depend on one — and `own` — its other
# conditions: its own `if:` (describe_condition()) plus a condition shared
# by all jobs of the reusable workflow it calls (e.g.
# cleanup-suggestion-branch.yml: "only if: PR from bot-suggest/
# branches"), "" if it always runs.
job_run_condition <- function(job, called) {
  words <- c(success = "succeeds", failure = "fails", cancelled = "is cancelled", always = "finishes")
  needs <- ""
  own <- character(0)

  cond <- job_condition(job)
  if (!is.na(cond$edge_label)) {
    what <- if (cond$edge_label %in% names(words)) {
      words[[cond$edge_label]]
    } else {
      cond$edge_label
    }
    needs <- sprintf("if %s %s", paste(unlist(job$needs), collapse = " and "), what)
  }
  if (!is.na(cond$note)) {
    own <- c(own, cond$note)
  }

  ref <- parse_workflow_ref(job$uses)
  inner <- if (!is.null(ref)) {
    called[[ref$key]]$workflow
  } else {
    NULL
  }
  if (!is.null(inner) && length(inner$jobs) > 0) {
    notes <- unique(vapply(inner$jobs, function(ij) {
      n <- job_condition(ij)$note
      if (is.na(n)) {
        ""
      } else {
        n
      }
    }, character(1)))
    if (length(notes) == 1 && nzchar(notes)) {
      own <- c(own, notes)
    }
  }
  list(needs = needs, own = paste(own, collapse = ", "))
}
