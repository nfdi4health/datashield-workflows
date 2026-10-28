# Which steps each plan step builds on: its `depends_on` list if the plan
# gives one (step ids, all earlier in the plan — scripts run in plan
# order), else every step before it. A step is only written once the steps
# it depends on passed (draft_steps_in_order()); `depends_on: []` makes a
# step independent. Returns a list step id -> character vector of ids.
# The plan was checked by validate_analysis_plan().
step_dependencies <- function(plan) {
  ids <- vapply(plan$steps, function(s) s$id, character(1))
  deps <- lapply(seq_along(plan$steps), function(i) {
    s <- plan$steps[[i]]
    if ("depends_on" %in% names(s)) {
      as.character(unlist(s$depends_on))
    } else {
      ids[seq_len(i - 1)]
    }
  })
  stats::setNames(deps, ids)
}
