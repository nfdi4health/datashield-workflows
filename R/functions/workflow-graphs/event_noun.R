# A GitHub event name as used in conditions: "scheduled run" for
# schedule, "pull request", "push", "manual run" for workflow_dispatch —
# otherwise the name with spaces ("repository dispatch").
event_noun <- function(event) {
  nouns <- c(schedule = "scheduled run", pull_request = "pull request", pull_request_target = "pull request",
             push = "push", workflow_dispatch = "manual run", workflow_call = "call from another workflow")
  if (event %in% names(nouns)) {
    nouns[[event]]
  } else {
    gsub("_", " ", event)
  }
}
