# The papers that count for a field: found by its current search (`query`)
# and within its sample of their month, i.e. their key in the field's
# order at most the month's threshold (read_months_state()). A paper read
# for another field, or outside the sample now, doesn't count, so each
# field's papers stay a random sample. `months` limits them to the round.
field_papers <- function(reg, state, field_name, query, months) {
  st <- state[state$field == field_name & state$query == query & state$month %in% months, , drop = FALSE]
  thresholds <- stats::setNames(st$threshold, st$month)
  Filter(function(p) {
    fb <- p$found_by[[field_name]]
    th <- thresholds[p$month]
    !is.null(fb) && identical(fb$query, query) && !is.na(th) && nzchar(th) && fb$key <= th
  }, reg$papers)
}
