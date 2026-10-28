# What a workflow of the repository produces, per config/workflow-outcomes.yml
# (`config`, read with read_config_yaml(): a project's copy merges over it): the
# outcomes listed for the workflow file itself, and per job those of the
# reusable workflow it calls. An entry is a short name from
# `config$outcomes` or its own wording; "{name}" is filled in with the
# job's input of that name, else the called workflow's default. An entry
# {outcome, only-on} adds "only if: <event>" — for results that depend on
# the event rather than on a job's `if:`.
#
# Returns a list of list(text, job, needs, condition), without duplicates:
# `job` is the producing job's ID (NA for the workflow file's own
# entries), `needs` the result of other jobs it waits for ("if check
# fails"), `condition` its other conditions (job_run_condition()).
workflow_outcomes <- function(workflow, called, config) {
  one <- function(entry, job_id = NA, run = list(needs = "", own = ""), job = NULL, inner = NULL) {
    only_on <- NULL
    if (is.list(entry)) {
      only_on <- entry[["only-on"]]
      entry <- entry$outcome
    }
    text <- if (!is.null(config$outcomes[[entry]])) {
      config$outcomes[[entry]]
    } else {
      entry
    }
    for (name in regmatches(text, gregexpr("(?<=\\{)[A-Za-z0-9_-]+(?=\\})", text, perl = TRUE))[[1]]) {
      value <- job$with[[name]]
      if (is.null(value)) {
        value <- inner$triggers$workflow_call$inputs[[name]]$default
      }
      if (!is.null(value)) {
        text <- gsub(sprintf("{%s}", name), as.character(value), text, fixed = TRUE)
      }
    }
    conditions <- character(0)
    if (!is.null(only_on)) {
      conditions <- c(conditions, paste("only if:", event_noun(only_on)))
    }
    if (nzchar(run$own)) {
      conditions <- c(conditions, run$own)
    }
    list(text = text, job = job_id, needs = run$needs, condition = paste(conditions, collapse = ", "))
  }

  out <- lapply(config$workflows[[file.path(".github/workflows", workflow$file)]], one)
  for (job_id in names(workflow$jobs)) {
    job <- workflow$jobs[[job_id]]
    ref <- parse_workflow_ref(job$uses)
    if (is.null(ref) || is.null(config$workflows[[ref$id]])) {
      next
    }
    run <- job_run_condition(job, called)
    inner <- called[[ref$key]]$workflow
    out <- c(out, lapply(config$workflows[[ref$id]], one, job_id = job_id, run = run, job = job, inner = inner))
  }
  unique(out)
}
