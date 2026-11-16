# How far the current round has got, per field: months complete (of the
# months in `months`), papers of the samples read, and the samples' size
# (for months not searched yet, the target stands in for it). `queries`
# names each field's current search fingerprint.
watch_progress <- function(state, fields, months, target, queries) {
  rows <- lapply(fields, function(f) {
    st <- state[state$field == f$name & state$month %in% months, , drop = FALSE]
    done <- vapply(months, function(m) month_complete(st[st$month == m, , drop = FALSE], queries[[f$name]], target), logical(1))
    size <- vapply(months, function(m) {
      r <- st[st$month == m, , drop = FALSE]
      if (nrow(r) == 1 && identical(r$query, queries[[f$name]])) min(target, r$total) else target
    }, numeric(1))
    read <- sum(st$sample_read[st$query == queries[[f$name]]], na.rm = TRUE)
    data.frame(field = f$name, months_complete = sum(done), months = length(months),
      papers_read = min(read, sum(size)), sample_size = sum(size))
  })
  do.call(rbind, rows)
}
