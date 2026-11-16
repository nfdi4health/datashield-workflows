# Writes the sampling state (read_months_state()), sorted by field and
# month, newest first.
write_months_state <- function(state, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  state <- state[order(state$field, -as.numeric(gsub("-", "", state$month))), , drop = FALSE]
  utils::write.csv(state, file.path(dir, "months.csv"), row.names = FALSE, na = "")
}
