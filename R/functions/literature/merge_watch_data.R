# A month's data file of the literature watch with this run's queries
# merged in: a query run again replaces its entry, the others stay (so a
# re-run of one query keeps the month's other results). `old` is the
# existing file's content or NULL.
merge_watch_data <- function(old, month, mode, entries) {
  data <- old %||% list()
  data$month <- month
  data$mode <- mode
  queries <- data$queries %||% list()
  for (name in names(entries)) queries[[name]] <- entries[[name]]
  data$queries <- queries
  data
}
