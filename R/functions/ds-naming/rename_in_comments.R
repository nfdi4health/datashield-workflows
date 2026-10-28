# Applies the renames (fn, old, new) to calls in plain comments of an R
# file (`# res <- fn(old = 1)`, often switched-off tests), so that code
# still works when it is switched back on. Roxygen lines (#') are handled
# by rename_in_roxygen(). Returns list(lines, done).
rename_in_comments <- function(lines, renames) {
  idx <- which(grepl("^\\s*#", lines) & !grepl("^\\s*#'", lines))
  if (length(idx) == 0) {
    return(list(lines = lines, done = 0))
  }
  prefix <- sub("^(\\s*#+).*$", "\\1", lines[idx])
  text <- substring(lines[idx], nchar(prefix) + 1)
  done <- 0
  for (r in seq_len(nrow(renames))) {
    res <- rename_call_args_text(text, renames$fn[r], renames$old[r], renames$new[r])
    text <- res$lines
    done <- done + res$done
  }
  if (done > 0) {
    lines[idx] <- paste0(prefix, text)
  }
  list(lines = lines, done = done)
}
