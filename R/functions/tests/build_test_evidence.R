# History evidence for judging a failing existing test: when the function
# file and each of its test files last changed, and which changed later,
# and — in a PR or push run (base_rev set: the state before this run's
# changes, from determine-changes.sh) — whether these changes touched the
# function without touching its tests, plus the function file's diff. A
# function changed after its test hints at an outdated test; a test that
# is newer than the code it fails on hints at a bug. Claude weighs this,
# R doesn't decide. `test_paths` are the function's existing test files
# (find_test_files()).
build_test_evidence <- function(function_file, test_paths, base_rev) {
  # system2() passes arguments through the shell unquoted — quote them.
  git <- function(...) suppressWarnings(system2("git", shQuote(c(...)), stdout = TRUE, stderr = FALSE))
  last_change <- function(path) {
    info <- git("log", "-1", "--format=%ct|%cs %h by %an: %s", "--", path)
    if (length(info) == 0) {
      return(NULL)
    }
    parts <- strsplit(info[1], "|", fixed = TRUE)[[1]]
    list(time = as.numeric(parts[1]), text = paste(parts[-1], collapse = "|"))
  }

  changed_text <- function(change) {
    if (is.null(change)) {
      return("not committed yet")
    }
    change$text
  }

  fn_change <- last_change(function_file)
  lines <- sprintf("Function file `%s` last changed: %s", function_file, changed_text(fn_change))

  if (length(test_paths) == 0) {
    lines <- c(lines, "No test file exists yet.")
  }
  for (test_path in test_paths) {
    test_change <- last_change(test_path)
    lines <- c(lines, sprintf("Test file `%s` last changed: %s", test_path, changed_text(test_change)))
    if (!is.null(fn_change) && !is.null(test_change)) {
      order <- if (fn_change$time > test_change$time) {
        "The function file changed after this test file."
      } else if (fn_change$time < test_change$time) {
        "This test file changed after the function file."
      } else {
        "Both last changed in the same commit."
      }
      lines <- c(lines, order)
    }
  }

  if (nzchar(base_rev)) {
    diff <- git("diff", base_rev, "HEAD", "--", function_file)
    tests_touched <- length(test_paths) > 0 && length(git("diff", "--name-only", base_rev, "HEAD", "--", test_paths)) > 0
    function_change <- "did not change"
    if (length(diff) > 0) {
      function_change <- "changed"
    }
    tests_change <- "did not change"
    if (tests_touched) {
      tests_change <- "changed as well"
    }
    lines <- c(lines, sprintf(
      "In the changes under review, the function file %s and its test files %s.",
      function_change, tests_change
    ))
    if (length(diff) > 0) {
      lines <- c(lines, "", "Diff of the function file in the changes under review:", "```diff", diff, "```")
    }
  }

  paste(lines, collapse = "\n")
}
