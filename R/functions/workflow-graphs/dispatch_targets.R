# The repository's workflows a dispatch (from job_dispatches()) starts:
# for repository_dispatch those listening to that event type (or to all
# types), for workflow_dispatch the one named by file or `name:`, as
# `gh workflow run` accepts both. Returns their file names.
dispatch_targets <- function(dispatch, workflows) {
  hits <- Filter(function(wf) {
    if (identical(dispatch$kind, "repository_dispatch")) {
      if (!"repository_dispatch" %in% names(wf$triggers)) {
        return(FALSE)
      }
      types <- unlist(wf$triggers$repository_dispatch$types)
      is.null(types) || dispatch$target %in% types
    } else {
      "workflow_dispatch" %in% names(wf$triggers) && dispatch$target %in% c(wf$file, wf$name)
    }
  }, workflows)
  vapply(hits, function(wf) wf$file, character(1))
}
