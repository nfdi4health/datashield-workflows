# The main loop of the roxygen and test bots: each file of
# files_to_check.txt is parsed (parse_r_file(); a file without a function
# is skipped) and handed to `review_file(f, parsed, state)`, which reviews
# its function and returns list(state, stats, updated): the suggestion
# state with this file's findings merged in, the counts of new, crossed
# out and repeated findings (c(new, crossed, repeats)), and the files it
# changed for the bot to propose. Anything else it returns is kept per
# file in `results`. Returns the final state, the summed stats, all
# changed files in order, and the per-file results.
review_files <- function(files, state, review_file) {
  stats <- c(new = 0L, crossed = 0L, repeats = 0L)
  updated <- character(0)
  results <- list()
  for (f in files) {
    parsed <- tryCatch(parse_r_file(f), error = function(e) {
      message(sprintf("Skipping %s: %s", f, conditionMessage(e)))
      NULL
    })
    if (is.null(parsed)) {
      next
    }
    out <- review_file(f, parsed, state)
    state <- out$state
    stats <- stats + out$stats
    updated <- c(updated, out$updated)
    results[[f]] <- out
  }
  list(state = state, stats = stats, updated = updated, results = results)
}
