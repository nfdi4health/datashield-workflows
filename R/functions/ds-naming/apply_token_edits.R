# Replaces tokens in `lines`: `edits` is a data frame line, col (parser
# column, col_to_index()), old, new. Each edit is checked — the text at
# that place must be `old` — and skipped with a warning otherwise, so a
# wrong position can never change anything else. Edits on one line are
# applied right to left. Returns list(lines, done, skipped).
apply_token_edits <- function(lines, edits) {
  done <- 0
  skipped <- character(0)
  if (nrow(edits) == 0) {
    return(list(lines = lines, done = 0, skipped = skipped))
  }
  edits$index <- mapply(function(l, c) col_to_index(lines[l], c), edits$line, edits$col)
  edits <- edits[order(edits$line, -edits$index), ]
  for (k in seq_len(nrow(edits))) {
    e <- edits[k, ]
    ln <- lines[e$line]
    if (is.na(e$index) || substr(ln, e$index, e$index + nchar(e$old) - 1) != e$old) {
      skipped <- c(skipped, sprintf("line %d: `%s` not found where expected", e$line, e$old))
      next
    }
    lines[e$line] <- paste0(substr(ln, 1, e$index - 1), e$new, substr(ln, e$index + nchar(e$old), nchar(ln)))
    done <- done + 1
  }
  list(lines = lines, done = done, skipped = skipped)
}
