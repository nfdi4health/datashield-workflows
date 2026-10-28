# For a function without tests: up to `n` existing test files of other
# functions, as examples of how this package writes its tests (how they
# connect, set up and clean up). In a categorised repository one file per
# most frequent category, else from all test files; in each case the file
# of median size — typical rather than trivial or huge. Returns
# read_test_file() entries.
example_test_files <- function(scheme, n = 2) {
  dir <- file.path("tests", "testthat")
  files <- list.files(dir, pattern = "^test-.*\\.[Rr]$", full.names = TRUE)
  if (length(files) == 0) {
    return(list())
  }

  pick_median <- function(paths) {
    sizes <- file.size(paths)
    paths[order(abs(sizes - stats::median(sizes)))[1]]
  }
  groups <- if (isTRUE(scheme$categorised)) {
    lapply(utils::head(scheme$categories, n), function(cat) files[startsWith(basename(files), sprintf("test-%s-", cat))])
  } else {
    list(files)
  }
  picked <- unique(unlist(lapply(Filter(length, groups), pick_median)))
  if (!isTRUE(scheme$categorised) && length(files) > 1) {
    picked <- unique(c(picked, pick_median(setdiff(files, picked))))
  }
  lapply(utils::head(picked, n), read_test_file)
}
