# One trigger (event + its settings from the workflow's `on:`) in words:
# "PR into dev", "PR closed", "Push to main", "Manual run",
# "Dispatch: release-publish", "Monthly (day 1)", … Used for the
# start boxes of the situation diagrams and the table. Path filters are
# not part of it, see event_filter().
describe_trigger <- function(event, settings) {
  list_of <- function(x) paste(unlist(x), collapse = ", ")

  if (event %in% c("pull_request", "pull_request_target")) {
    types <- unlist(settings$types)
    if (identical(types, "closed")) {
      return("PR closed")
    }
    what <- "PR"
    if (length(types) > 0) {
      what <- sprintf("PR %s", list_of(types))
    }
    if (!is.null(settings$branches)) {
      what <- sprintf("%s into %s", what, list_of(settings$branches))
    }
    return(what)
  }

  if (event == "push") {
    if (!is.null(settings$branches)) {
      return(sprintf("Push to %s", list_of(settings$branches)))
    }
    if (!is.null(settings$tags)) {
      return("Tag push")
    }
    return("Push")
  }

  if (event == "schedule") {
    crons <- vapply(settings, function(s) s$cron, character(1))
    text <- "on a schedule"
    if (length(crons) == 1) {
      text <- describe_cron(crons)
    }
    return(paste0(toupper(substr(text, 1, 1)), substring(text, 2)))
  }

  if (event == "repository_dispatch") {
    if (is.null(settings$types)) {
      return("Dispatch")
    }
    return(sprintf("Dispatch: %s", list_of(settings$types)))
  }

  if (event == "release") {
    if (is.null(settings$types)) {
      return("Release")
    }
    return(sprintf("Release %s", list_of(settings$types)))
  }

  switch(event,
    workflow_dispatch = "Manual run",
    workflow_run = sprintf("After: %s", list_of(settings$workflows)),
    workflow_call = "Called by other workflows",
    event
  )
}
