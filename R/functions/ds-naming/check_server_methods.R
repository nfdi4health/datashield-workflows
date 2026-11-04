# Where a server package declares its methods (`function$server$methods_file`
# in the package rules; DESCRIPTION is not the place) and whether each
# declared method has a function behind it. Methods that point to another
# package (alias=base::mean) have theirs there. Returns the problems as
# sentences. Report only.
check_server_methods <- function(pkg, package_rules) {
  methods_file <- package_rules$`function`$server$methods_file
  problems <- character(0)
  if (!file.exists(file.path(pkg$dir, methods_file))) {
    problems <- c(problems, sprintf("No `%s`.", methods_file))
  }
  in_description <- intersect(c("AggregateMethods", "AssignMethods"), colnames(read.dcf(file.path(pkg$dir, "DESCRIPTION"))))
  if (length(in_description) > 0) {
    problems <- c(problems, sprintf("Methods are declared in `DESCRIPTION` (%s), not in `%s`.", paste(in_description, collapse = ", "), methods_file))
  }
  local <- pkg$methods[setdiff(names(pkg$methods), attr(pkg$methods, "other_package"))]
  functions <- vapply(pkg$defs, function(d) d$name, character(1))
  missing <- setdiff(unique(unname(local)), functions)
  if (length(missing) > 0) {
    problems <- c(problems, sprintf("Declared without a function: %s.", paste(sprintf("`%s`", missing), collapse = ", ")))
  }
  problems
}
