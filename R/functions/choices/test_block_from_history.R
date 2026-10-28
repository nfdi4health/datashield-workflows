# The bot's version of a test_that() block that is no longer in the file
# (the user unticked it and ticks it again): searched in the bot branch's
# history (HEAD, newest first) for a version of the file with a block of
# that name — other than `except` (the base branch's version, for an
# updated test). NULL if none is found.
test_block_from_history <- function(path, description, except = NULL) {
  commits <- suppressWarnings(system2("git", shQuote(c("log", "--format=%H", "HEAD", "--", path)), stdout = TRUE, stderr = FALSE))
  for (sha in commits) {
    block <- test_block_text(git_file_at(sha, path), description)
    if (!is.null(block) && !identical(block, except)) {
      return(block)
    }
  }
  NULL
}
