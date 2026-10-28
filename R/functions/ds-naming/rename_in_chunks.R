# Applies the renames (fn, old, new) to the R code chunks of an R
# Markdown or Quarto file (```{r ...} ... ```): calls to `fn` with
# `old = ...` (rename_call_args_text()). Prose around them is left alone.
# Returns list(lines, done).
rename_in_chunks <- function(lines, renames) {
  done <- 0
  opens <- grep("^\\s*```+\\s*\\{r[ ,}]", lines)
  for (o in opens) {
    close <- o + which(grepl("^\\s*```+\\s*$", lines[-(1:o)]))[1]
    if (is.na(close) || close <= o + 1) {
      next
    }
    span <- (o + 1):(close - 1)
    for (r in seq_len(nrow(renames))) {
      res <- rename_call_args_text(lines[span], renames$fn[r], renames$old[r], renames$new[r])
      lines[span] <- res$lines
      done <- done + res$done
    }
  }
  list(lines = lines, done = done)
}
