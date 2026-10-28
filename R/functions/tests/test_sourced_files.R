# Files the test support files (test_support_files()) source(), e.g.
# dsBaseClient's connection_to_datasets/*.R, where the connection helpers
# the tests call are defined. Only plain string paths are followed,
# relative to tests/testthat/ (where testthat runs) or, failing that, to
# the package root. Returns the existing paths, in order of first mention.
test_sourced_files <- function(support_files) {
  dir <- file.path("tests", "testthat")
  pattern <- "source\\(\\s*(testthat::)?(test_path\\(\\s*)?[\"']([^\"']+\\.[Rr])[\"']"
  found <- unlist(lapply(support_files, function(path) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[!grepl("^\\s*#", lines)]
    m <- regmatches(lines, regexec(pattern, lines))
    vapply(Filter(function(x) length(x) == 4, m), function(x) x[4], character(1))
  }))
  paths <- vapply(found, function(p) {
    if (file.exists(file.path(dir, p))) {
      file.path(dir, p)
    } else if (file.exists(p)) {
      p
    } else {
      NA_character_
    }
  }, character(1), USE.NAMES = FALSE)
  setdiff(unique(paths[!is.na(paths)]), support_files)
}
