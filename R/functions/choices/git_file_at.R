# A file's content at a revision (`rev`, e.g. the base branch or a commit
# of the bot branch) as one string, or NULL if it doesn't exist there.
git_file_at <- function(rev, path) {
  lines <- suppressWarnings(system2("git", shQuote(c("show", sprintf("%s:%s", rev, path))), stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(lines, "status"))) {
    return(NULL)
  }
  paste(lines, collapse = "\n")
}
