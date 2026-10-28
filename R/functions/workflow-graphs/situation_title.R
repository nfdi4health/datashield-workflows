# The heading above a situation diagram, as a sentence: "When a pull
# request into dev is opened or updated", "When a pull request is closed",
# "On a push to dev", "On a schedule", … — the diagram's start box keeps
# the short form (describe_trigger()).
situation_title <- function(event, settings) {
  list_of <- function(x) paste(unlist(x), collapse = ", ")

  if (event %in% c("pull_request", "pull_request_target")) {
    into <- ""
    if (!is.null(settings$branches)) {
      into <- sprintf(" into %s", list_of(settings$branches))
    }
    types <- unlist(settings$types)
    if (identical(types, "closed")) {
      return(sprintf("When a pull request%s is closed", into))
    }
    if (length(types) > 0) {
      return(sprintf("When a pull request%s is %s", into, list_of(types)))
    }
    return(sprintf("When a pull request%s is opened or updated", into))
  }

  if (event == "push") {
    if (!is.null(settings$branches)) {
      return(sprintf("On a push to %s", list_of(settings$branches)))
    }
    return("On a push")
  }

  if (event == "repository_dispatch") {
    if (is.null(settings$types)) {
      return("When a dispatch event is sent")
    }
    return(sprintf("When the %s event is sent", list_of(settings$types)))
  }

  switch(event,
    schedule = "On a schedule",
    workflow_run = sprintf("After %s", list_of(settings$workflows)),
    release = "When a release is published",
    describe_trigger(event, settings)
  )
}
