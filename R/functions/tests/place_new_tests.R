# Claude's new tests, filtered and placed: filter_generated_tests() (reason
# accepted, name and assertions not taken), without the ones the user
# declined (`declined`: descriptions), each into its file —
# test-<name>.R, or test-<category>-<name>.R in a categorised repository
# (an unknown category drops the test) — and assembled into test_that()
# blocks per file (assemble_test_block()). `name` is the R file's name
# (test_file_name()). Returns list(tests: the kept ones, targets: their
# file per test, by_file: assembled blocks per path).
place_new_tests <- function(result, test_files, blocks, declined, scheme, name, accept_reasons, function_name) {
  tests <- if (isTRUE(result$needs_tests)) {
    all_content <- paste(vapply(test_files, function(t) t$content, character(1)), collapse = "\n")
    all_descriptions <- unlist(lapply(blocks, function(b) vapply(b, function(x) x$description, character(1))))
    filter_generated_tests(result$tests, all_content, accept_reasons, function_name, all_descriptions)
  } else {
    list()
  }
  for (t in Filter(function(t) t$description %in% declined, tests)) {
    message(sprintf("%s: not proposing '%s' again — declined.", function_name, t$description))
  }
  tests <- Filter(function(t) !t$description %in% declined, tests)

  target_of <- function(t) {
    if (!scheme$categorised) {
      return(test_file_path(name))
    }
    if (!isTRUE(t$category %in% scheme$categories)) {
      message(sprintf("%s: dropping test '%s' — unknown category '%s'.", function_name, t$description, t$category))
      return(NA_character_)
    }
    test_file_path(name, t$category)
  }
  targets <- vapply(tests, target_of, character(1))

  by_file <- list()
  for (path in unique(targets[!is.na(targets)])) {
    assembled <- tryCatch(assemble_test_block(tests[targets %in% path], function_name), error = function(e) {
      message(sprintf("Failed to assemble test blocks for %s: %s", function_name, conditionMessage(e)))
      character(0)
    })
    if (length(assembled) > 0) {
      by_file[[path]] <- assembled
    }
  }
  list(tests = tests, targets = targets, by_file = by_file)
}
