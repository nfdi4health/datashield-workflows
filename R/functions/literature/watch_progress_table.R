# The literature watch's progress as a table for other tools (e.g. a
# dashboard reading progress.csv from the data branch): per field its
# current search, months complete, papers read and usable, the round's
# sample size, the round and the date.
watch_progress_table <- function(progress, by_field, queries, target, months, today) {
  usable <- vapply(progress$field, function(f) sum(vapply(by_field[[f]], function(p) isTRUE(p$usable), logical(1))), numeric(1))
  data.frame(field = progress$field, query = unlist(queries[progress$field]),
    months_complete = progress$months_complete, months = progress$months,
    papers_read = progress$papers_read, papers_usable = usable, sample_size = progress$sample_size,
    target_per_month = target, first_month = utils::tail(months, 1), last_month = months[1],
    updated = as.character(today), row.names = NULL)
}
