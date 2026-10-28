# Claude's decisions on existing tests (`decisions`), per test file:
# each decision belongs to the file it names (with a single test file, a
# decision naming no or another file belongs to it); an update or deletion
# the user declined (`declined_updates`, `declined_deletes`: descriptions)
# isn't proposed again. Each file's decisions pass review_existing_tests().
# A report of a possible bug Claude is sure enough of (`confidences`,
# code-issue-confidence) becomes a possible bug in the code, any other
# report a note; a failing existing test Claude left without a decision is
# a note too. Returns list(reviews: per path, notes, bugs).
sort_test_decisions <- function(decisions, paths, blocks, baseline, declined_updates, declined_deletes, confidences, function_name) {
  declined <- function(d) {
    (identical(d$action, "update") && d$description %in% declined_updates) ||
      (identical(d$action, "delete") && d$description %in% declined_deletes)
  }
  for (d in Filter(declined, decisions)) {
    message(sprintf("%s: not proposing to %s '%s' again — declined.", function_name, d$action, d$description))
  }
  decisions <- Filter(Negate(declined), decisions)

  file_of <- function(d) {
    name <- if (is.null(d$test_file)) {
      ""
    } else {
      d$test_file
    }
    hit <- paths[basename(paths) == name]
    if (length(hit) == 1) {
      hit
    } else if (length(paths) == 1) {
      paths
    } else {
      NA_character_
    }
  }
  decision_paths <- vapply(decisions, file_of, character(1))
  for (d in decisions[is.na(decision_paths)]) {
    message(sprintf("%s: ignoring decision on '%s' — unknown test file '%s'.", function_name, d$description, d$test_file))
  }

  out <- list(reviews = list(), notes = list(), bugs = list())
  for (path in paths) {
    mine <- decisions[decision_paths %in% path]
    review <- review_existing_tests(mine, blocks[[path]], baseline[[path]], function_name)
    for (n in review$notes) {
      n$file <- path
      if (isTRUE(n$possible_bug) && isTRUE(n$confidence %in% confidences)) {
        out$bugs[[length(out$bugs) + 1]] <- c(n, list(origin = "existing"))
      } else {
        out$notes[[length(out$notes) + 1]] <- n
      }
    }
    decided <- vapply(mine, function(d) d$description, character(1))
    for (r in Filter(function(r) !isTRUE(r$passed) && !r$description %in% decided, baseline[[path]])) {
      out$notes[[length(out$notes) + 1]] <- list(file = path, description = r$description, text = sprintf("fails, no change proposed. %s", gsub("\\s+", " ", r$message)))
    }
    out$reviews[[path]] <- review
  }
  out
}
