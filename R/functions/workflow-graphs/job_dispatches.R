# What one job sends to start other workflows: its own steps
# (workflow_dispatches() on a one-job workflow) plus, for a job that calls
# a reusable workflow, everything that call sends further down
# (`called` from resolve_called_workflows()).
job_dispatches <- function(job, called) {
  own <- workflow_dispatches(list(jobs = list(job)))
  ref <- parse_workflow_ref(job$uses)
  via_call <- if (is.null(ref) || is.null(called[[ref$key]])) {
    list()
  } else {
    called[[ref$key]]$dispatches
  }
  unique(c(own, via_call))
}
