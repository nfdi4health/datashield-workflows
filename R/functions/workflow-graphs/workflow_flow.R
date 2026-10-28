# One workflow's part of a situation diagram (situation_diagram()): its
# outcomes `outs` (workflow_outcomes(), fitted by situation_outcomes()) and
# the arrows between its box, those outcomes and the workflows it starts
# (`chains`). Outcomes follow the order of the jobs that produce them: a
# job that needs another starts from that job's outcomes, labelled with
# the result it waits for ("if check fails"); a job without outcomes of
# its own passes its incoming arrows through; a chain starts from the
# outcome its sending job depends on. A condition on every arrow leaving
# the box is returned as `box_note` and dropped from those arrows.
# Returns list(outcome_text, edges, box_note): `outcome_text` a named list,
# key "file|job|i" -> wording; `edges` a list of list(from, to, label,
# dotted), with outcome keys or Mermaid IDs (the box, started workflows).
workflow_flow <- function(wf, outs, chains) {
  box <- mermaid_id("wf", wf$file)
  label_of <- function(parts) paste(Filter(nzchar, parts), collapse = ", ")
  jobs_out <- vapply(outs, function(o) {
    if (is.na(o$job)) {
      return("")
    }
    o$job
  }, character(1))
  keys <- sprintf("%s|%s|%d", wf$file, jobs_out, seq_along(outs))
  outcome_text <- stats::setNames(lapply(outs, function(o) o$text), keys)

  # Where arrows into a job come from: its own outcomes, or — for a job
  # without outcomes — what its needs lead to, down to the workflow box.
  sources <- function(job, seen = character(0)) {
    if (job %in% seen) {
      return(box)
    }
    mine <- keys[jobs_out == job]
    if (length(mine) > 0) {
      return(mine)
    }
    needs <- unlist(wf$jobs[[job]]$needs)
    if (length(needs) == 0) {
      return(box)
    }
    unique(unlist(lapply(needs, sources, seen = c(seen, job))))
  }

  edges <- list()
  for (i in seq_along(outs)) {
    o <- outs[[i]]
    needs <- if (is.na(o$job)) {
      NULL
    } else {
      unlist(wf$jobs[[o$job]]$needs)
    }
    froms <- if (length(needs) == 0) {
      box
    } else {
      unique(unlist(lapply(needs, sources)))
    }
    for (fr in froms) {
      edges[[length(edges) + 1]] <- list(from = fr, to = keys[i], label = label_of(c(o$needs, o$condition)), dotted = FALSE)
    }
  }
  for (ch in Filter(function(ch) identical(ch$from, wf$file), chains)) {
    froms <- if (is.na(ch$job)) {
      box
    } else {
      sources(ch$job)
    }
    for (fr in froms) {
      edges[[length(edges) + 1]] <- list(from = fr, to = mermaid_id("wf", ch$to), label = ch$label, dotted = TRUE)
    }
  }

  # A condition on every arrow leaving the box goes into the box.
  box_note <- NULL
  from_box <- Filter(function(e) identical(e$from, box) && !e$dotted, edges)
  shared <- unique(vapply(from_box, function(e) e$label, character(1)))
  if (length(from_box) > 0 && length(shared) == 1 && nzchar(shared)) {
    box_note <- shared
    edges <- lapply(edges, function(e) { if (identical(e$from, box) && !e$dotted) {
      e$label <- ""
    }; e })
  }
  list(outcome_text = outcome_text, edges = edges, box_note = box_note)
}
