# Links between the repository's own workflows, for the overview: A starts
# B when a job of A (or a workflow it calls) sends a dispatch B listens to
# (job_dispatches(), dispatch_targets()), or when B runs on `workflow_run`
# after A (B names A in `workflows:`). Returns a list of
# list(from, to, job, label) — `from`/`to` are file names, `job` the
# sending job (NA for workflow_run).
workflow_chains <- function(workflows, called) {
  chains <- list()
  add <- function(from, to, job, label) chains[[length(chains) + 1]] <<- list(from = from, to = to, job = job, label = label)

  for (wf in workflows) {
    for (job_id in names(wf$jobs)) {
      for (d in job_dispatches(wf$jobs[[job_id]], called)) {
        label <- if (identical(d$kind, "repository_dispatch")) {
          sprintf("dispatch: %s", d$target)
        } else {
          "workflow_dispatch"
        }
        for (to in dispatch_targets(d, workflows)) {
          add(wf$file, to, job_id, label)
        }
      }
    }
    listens_to <- unlist(wf$triggers$workflow_run$workflows)
    for (other in workflows) {
      if (other$name %in% listens_to) {
        add(other$file, wf$file, NA, "after it runs")
      }
    }
  }
  unique(chains)
}
