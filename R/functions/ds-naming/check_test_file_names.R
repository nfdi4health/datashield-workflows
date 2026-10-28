# Test files of a package (`pkg`, read_ds_package()) that don't follow
# `tests` in the rules: stage 1 the file name pattern, stage 2 its target
# part must be a function of the package, a listed topic, or (datachk
# tests) a test dataset. Helper and setup files are exempt. Returns a data
# frame file, problem.
check_test_file_names <- function(pkg, rules) {
  files <- basename(list.files(file.path(pkg$dir, "tests", "testthat"), pattern = "\\.[Rr]$"))
  exempt <- vapply(files, function(f) any(vapply(unlist(rules$tests$helpers_allowed), function(p) grepl(p, f) || f == p, logical(1))), logical(1))
  files <- files[!exempt & startsWith(files, "test")]
  functions <- vapply(pkg$defs, function(d) d$name, character(1))
  problems <- list()
  for (f in files) {
    m <- regexpr(rules$tests$pattern, f, perl = TRUE)
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
    target <- group("target")
    is_dataset <- grepl("datachk", group("category"))
    if (!target %in% functions && !target %in% unlist(rules$tests$allowed_topics) && !is_dataset) {
      problems[[length(problems) + 1]] <- data.frame(file = f, problem = sprintf("`%s` is no function of the package or listed topic", target))
    }
  }
  if (length(problems) == 0) {
    data.frame(file = character(0), problem = character(0))
  } else {
    do.call(rbind, problems)
  }
}
