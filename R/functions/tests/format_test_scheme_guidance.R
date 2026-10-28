# How the repository names its test files, for the prompt. Plain
# repositories: new tests go into test-<name>.R, `name` being the R file's
# name without .R (test_file_name()). Categorised ones
# (detect_test_scheme()): Claude picks a category per new test, explained
# with the meanings from config/test-categories.yml (`meanings`, a named
# list); categories without a meaning are named with a pointer to their
# existing files. Marks which categories this R file already has a test
# file for (`existing_files`, from find_test_files()).
format_test_scheme_guidance <- function(scheme, meanings, name, existing_files) {
  if (!isTRUE(scheme$categorised)) {
    return(sprintf("New tests go into `%s`.", basename(test_file_path(name))))
  }
  has_file <- vapply(existing_files, function(f) f$category, character(1))
  lines <- vapply(scheme$categories, function(cat) {
    meaning <- meanings[[cat]] %||% sprintf("(no description; see the repository's existing `test-%s-*.R` files)", cat)
    existing <- ""
    if (cat %in% has_file) {
      existing <- sprintf(" This function already has `%s`.", basename(test_file_path(name, cat)))
    }
    sprintf("- `%s`: %s%s", cat, meaning, existing)
  }, character(1))
  paste(c(
    sprintf("This repository names its test files `test-<category>-<R file name>.R`, one file per purpose. Give each new test the category that fits; the script writes it into `test-<category>-%s.R` and creates that file if needed. The categories:", name),
    lines
  ), collapse = "\n")
}
