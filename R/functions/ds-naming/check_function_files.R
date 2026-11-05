# How a package's functions sit in their files (`function` in the package
# rules): one function per file (`one_function_per_file`, all functions)
# and the file named after a user-facing function (`file_name`, a template
# with <function>). Returns the problems as sentences. Report only.
check_function_files <- function(pkg, package_rules) {
  rules <- package_rules$`function`
  files <- vapply(pkg$defs, function(d) basename(d$file), character(1))
  names_of <- vapply(pkg$defs, function(d) d$name, character(1))
  problems <- character(0)
  if (isTRUE(rules$one_function_per_file)) {
    for (f in unique(files[duplicated(files)])) {
      problems <- c(problems, sprintf("`%s` holds several functions: %s.", f, paste(sprintf("`%s`", unique(names_of[files == f])), collapse = ", ")))
    }
  }
  for (i in which(names_of %in% pkg$user_facing)) {
    expected <- sub("<function>", names_of[i], rules$file_name, fixed = TRUE)
    if (!identical(files[i], expected)) {
      problems <- c(problems, sprintf("`%s` is in `%s`, expected `%s`.", names_of[i], files[i], expected))
    }
  }
  problems
}
