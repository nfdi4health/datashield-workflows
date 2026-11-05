# Test files of a package (`pkg`, read_ds_package()) that don't follow
# `tests` in the package rules: stage 1 the file name pattern (test_file_pattern()), stage 2 its function
# part must be a function of the package. Helper and setup files are exempt. Returns a data
# frame file, problem.
check_test_file_names <- function(pkg, package_rules) {
  files <- basename(list.files(file.path(pkg$dir, "tests", "testthat"), pattern = "\\.[Rr]$"))
  exempt <- vapply(files, function(f) any(vapply(unlist(package_rules$tests$helpers_allowed), function(p) grepl(p, f) || f == p, logical(1))), logical(1))
  files <- files[!exempt & startsWith(files, "test")]
  functions <- vapply(pkg$defs, function(d) d$name, character(1))
  pattern <- test_file_pattern(package_rules, pkg$side)
  problems <- list()
  for (f in files) {
    m <- regexpr(pattern, f, perl = TRUE)
    if (m < 0) {
      problems[[length(problems) + 1]] <- data.frame(file = f, problem = "name does not match the pattern")
      next
    }
    group <- function(g) {
      start <- attr(m, "capture.start")[1, g]
      if (start < 0) {
        ""
      } else {
        substr(f, start, start + attr(m, "capture.length")[1, g] - 1)
      }
    }
    target <- group("function")
    if (!target %in% functions) {
      problems[[length(problems) + 1]] <- data.frame(file = f, problem = sprintf("`%s` is no function of the package", target))
    }
  }
  if (length(problems) == 0) {
    data.frame(file = character(0), problem = character(0))
  } else {
    do.call(rbind, problems)
  }
}
