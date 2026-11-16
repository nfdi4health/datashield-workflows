# Whether a field's sample of a month (a row of read_months_state(), or
# NULL) is complete for the current search and target: searched with this
# search, for at least this target, and every paper of the sample read.
month_complete <- function(row, query, target) {
  !is.null(row) && nrow(row) == 1 && identical(row$query, query) && row$target >= target &&
    row$sample_read >= min(target, row$total)
}
