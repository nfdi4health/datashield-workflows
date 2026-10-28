# The table at the top of the overview — the quickest way in, and always
# readable on GitHub: one row per workflow (in the order given) with its
# name, its file (the only place the file is named; the diagrams leave it
# out), its triggers (with path filters), the reusable workflows it calls
# (full reference; "not readable" if resolve_called_workflows() couldn't
# read it), and what it produces (`outcomes`, file -> list of
# list(text, condition) from workflow_outcomes()) plus the workflows it
# starts (`chains`). A cell with several entries lists them as bullets.
# Returns Markdown lines.
workflow_summary_table <- function(workflows, called, outcomes, chains) {
  # Pipes would end the cell, asterisks in "R/**" would turn into bold.
  cell <- function(x) gsub("*", "\\*", gsub("|", "\\|", x, fixed = TRUE), fixed = TRUE)
  # Entries are already escaped; one stays plain, several become bullets.
  entries <- function(x) {
    if (length(x) == 0) {
      return("—")
    }
    if (length(x) == 1) {
      return(x)
    }
    paste0("• ", x, collapse = "<br>")
  }
  name_of <- stats::setNames(vapply(workflows, function(wf) wf$name, character(1)), vapply(workflows, function(wf) wf$file, character(1)))

  rows <- vapply(workflows, function(wf) {
    events <- names(wf$triggers)
    events <- events[order(match(events, trigger_order(), nomatch = length(trigger_order()) + 1))]
    runs_on <- vapply(events, function(e) {
      filter <- event_filter(wf$triggers[[e]])
      text <- describe_trigger(e, wf$triggers[[e]])
      if (nzchar(filter)) {
        text <- sprintf("%s (%s)", text, filter)
      }
      cell(text)
    }, character(1), USE.NAMES = FALSE)

    calls <- unique(unlist(lapply(wf$jobs, function(job) {
      ref <- parse_workflow_ref(job$uses)
      if (is.null(ref)) {
        return(NULL)
      }
      label <- ref$label
      if (!isTRUE(called[[ref$key]]$readable)) {
        label <- paste0(label, " (not readable)")
      }
      cell(label)
    })))

    produced <- vapply(outcomes[[wf$file]], function(o) {
      condition <- paste(Filter(nzchar, c(o$needs, o$condition)), collapse = ", ")
      if (nzchar(condition)) {
        sprintf("%s — *%s*", cell(o$text), cell(condition))
      } else {
        cell(o$text)
      }
    }, character(1))
    starts <- unique(vapply(Filter(function(ch) identical(ch$from, wf$file), chains), function(ch) sprintf("starts **%s**", cell(name_of[[ch$to]])), character(1)))

    sprintf("| %s | `%s` | %s | %s | %s |",
            cell(wf$name), wf$file, entries(runs_on), entries(calls), entries(c(produced, starts)))
  }, character(1))

  c("| Name | File | Runs on | Calls | Produces |", "|---|---|---|---|---|", rows)
}
