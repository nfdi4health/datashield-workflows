# Keeps one of the data folder's lookup tables (queries.csv: every version
# of a field's search; readers.csv: every model and prompt that read
# papers) in step with what this run uses. `current` has the columns
# `fingerprint`, `group` (the field, or "reader") and the table's own
# columns. A fingerprint not yet active is added (status active, used from
# today); an active row of the same group with another fingerprint is
# retired (used until today). Rows are never deleted, so every fingerprint
# stored with a paper can be looked up. Returns the table.
update_lookup_table <- function(path, current, today) {
  table <- if (file.exists(path)) utils::read.csv(path, colClasses = "character", na.strings = "") else NULL
  cols <- c(names(current), "used_from", "used_until", "status")
  if (is.null(table)) table <- as.data.frame(stats::setNames(replicate(length(cols), character(0), simplify = FALSE), cols))
  today <- as.character(today)
  for (i in seq_len(nrow(current))) {
    row <- current[i, , drop = FALSE]
    active <- table$status == "active" & table$group == row$group
    if (any(active & table$fingerprint == row$fingerprint)) next
    table$used_until[active] <- today
    table$status[active] <- "retired"
    new <- cbind(row, used_from = today, used_until = NA, status = "active")
    table <- rbind(table, new[, cols])
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(table, path, row.names = FALSE, na = "")
  table
}
