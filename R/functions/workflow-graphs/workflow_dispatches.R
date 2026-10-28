# Events a workflow's own steps send to start other workflows — the links
# the overview draws between workflows. Only known forms are recognised,
# so an unknown one gives no arrow rather than a wrong one:
# - repository_dispatch: `gh api …/dispatches` with `event_type=<type>`,
#   or the peter-evans/repository-dispatch action (`event-type`);
# - workflow_dispatch: `gh workflow run <file or name>`, or the
#   benc-uk/workflow-dispatch action (`workflow`).
# Steps of called reusable workflows are not looked at here, see
# resolve_called_workflows(). Returns a list of list(kind, target).
workflow_dispatches <- function(workflow) {
  found <- list()
  add <- function(kind, target) found[[length(found) + 1]] <<- list(kind = kind, target = target)

  for (job in workflow$jobs) {
    for (step in job$steps) {
      run <- if (is.character(step$run)) {
        step$run
      } else {
        ""
      }
      if (grepl("dispatches", run, fixed = TRUE)) {
        type_pattern <- "event_type[\"']?\\s*[=:]\\s*[\"']?([A-Za-z0-9_.-]+)"
        for (t in regmatches(run, gregexpr(type_pattern, run, perl = TRUE))[[1]]) {
          add("repository_dispatch", sub(type_pattern, "\\1", t, perl = TRUE))
        }
      }
      for (t in regmatches(run, gregexpr("gh workflow run\\s+[\"']?[^\\s\"']+", run, perl = TRUE))[[1]]) {
        add("workflow_dispatch", sub("gh workflow run\\s+[\"']?", "", t, perl = TRUE))
      }

      uses <- if (is.character(step$uses)) {
        step$uses
      } else {
        ""
      }
      if (startsWith(uses, "peter-evans/repository-dispatch@") && !is.null(step$with[["event-type"]])) {
        add("repository_dispatch", step$with[["event-type"]])
      }
      if (startsWith(uses, "benc-uk/workflow-dispatch@") && !is.null(step$with$workflow)) {
        add("workflow_dispatch", step$with$workflow)
      }
    }
  }
  unique(found)
}
