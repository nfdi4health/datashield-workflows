# Follows the reusable workflows the repository's workflows call, all the
# way down (a called workflow may call further ones), to collect what each
# call sends in the end (workflow_dispatches()). Each distinct reference is
# read once; a reference already seen is not followed again (loop guard),
# and nothing deeper than `max_depth` is read. Composite actions used in
# steps are not opened — a dispatch sent from inside one is not found.
# Returns a named list, reference key -> list(ref, readable, dispatches,
# workflow), where `dispatches` includes everything sent further down and
# `workflow` is the parsed called file (for outcomes and conditions; NULL if
# not readable).
resolve_called_workflows <- function(workflows, max_depth = 5) {
  resolved <- list()

  visit <- function(ref, depth) {
    if (!is.null(resolved[[ref$key]])) {
      return(resolved[[ref$key]]$dispatches)
    }
    resolved[[ref$key]] <<- list(ref = ref, readable = FALSE, dispatches = list())  # loop guard
    if (depth > max_depth) {
      return(list())
    }

    wf <- fetch_called_workflow(ref)
    if (is.null(wf)) {
      message(sprintf("Could not read %s.", ref$label))
      return(list())
    }
    dispatches <- workflow_dispatches(wf)
    for (job in wf$jobs) {
      inner <- parse_workflow_ref(job$uses)
      if (!is.null(inner)) {
        dispatches <- c(dispatches, visit(inner, depth + 1))
      }
    }
    resolved[[ref$key]] <<- list(ref = ref, readable = TRUE, dispatches = unique(dispatches), workflow = wf)
    resolved[[ref$key]]$dispatches
  }

  for (wf in workflows) {
    for (job in wf$jobs) {
      ref <- parse_workflow_ref(job$uses)
      if (!is.null(ref)) {
        visit(ref, 1)
      }
    }
  }
  resolved
}
