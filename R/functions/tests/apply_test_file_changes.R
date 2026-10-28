# Applies the proposed changes to ONE test file and keeps only what
# passes: writes a candidate with all of them (new tests — inserted at
# test_insert_line() — updates and deletions), runs it with the package
# loaded from source, then rewrites the file from its ORIGINAL content
# with only the passing new tests and updates (plus the deletions). A
# failing candidate is never left in the proposed file. A file that
# didn't exist yet is created by new_test_file_content().
# Returns list(path: the file if it now differs, else NULL; passing_new;
# failing_new: run results of the failing new tests; kept_updates;
# failed_updates: descriptions).
apply_test_file_changes <- function(test_file, blocks, updates, deletes, test_blocks, result, function_name, package_name) {
  build <- function(new_blocks, kept) {
    if (!test_file$exists) {
      return(new_test_file_content(new_blocks, result, function_name))
    }
    rewrite_test_content(test_file$content, blocks, kept, deletes, new_blocks, test_insert_line(test_file$content, blocks))
  }
  passed_in <- function(results, description) {
    isTRUE(Find(function(r) identical(r$description, description), results)$passed)
  }

  write_test_file(test_file, build(test_blocks, updates))
  run_results <- tryCatch(run_test_blocks(test_file$path, package_name), error = function(e) {
    message(sprintf("Running candidate tests in %s failed: %s", test_file$path, conditionMessage(e)))
    list()
  })

  passing_new <- names(test_blocks)[vapply(names(test_blocks), function(d) passed_in(run_results, d), logical(1))]
  kept_updates <- updates[vapply(names(updates), function(d) passed_in(run_results, d), logical(1))]
  kept_new <- test_blocks[passing_new]
  final <- if (!test_file$exists && length(kept_new) == 0) {
    NULL
  } else {
    build(kept_new, kept_updates)
  }

  list(
    path = write_test_file(test_file, final),
    passing_new = passing_new,
    failing_new = Filter(function(r) r$description %in% setdiff(names(test_blocks), passing_new), run_results),
    kept_updates = kept_updates,
    failed_updates = setdiff(names(updates), names(kept_updates))
  )
}
