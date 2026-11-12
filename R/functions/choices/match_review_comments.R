# Review line comments people left on a bot PR, attached to the findings
# whose file they were made on (`comments` as from the GitHub API:
# path, line / original_line, body, user$login; bots' comments are left
# out). Returns a list: finding id -> comments (path, line, author, body
# cut to `max_chars`). A file-level match: a comment on a file with
# several findings is attached to each of them.
match_review_comments <- function(comments, entries, max_chars = 1000) {
  out <- list()
  for (c in comments) {
    if (identical(c$user$type, "Bot") || is.null(c$path)) {
      next
    }
    item <- list(path = c$path, line = c$line %||% c$original_line %||% NA, author = c$user$login %||% "",
                 body = substr(c$body %||% "", 1, max_chars))
    for (e in entries) {
      if (identical(e$file, c$path)) {
        key <- as.character(e$id)
        out[[key]] <- c(out[[key]] %||% list(), list(item))
      }
    }
  }
  out
}
