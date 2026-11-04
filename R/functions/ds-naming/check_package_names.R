# A package's name against `package` in the package rules: the template of
# its side, the pair (dsBase and dsBaseClient), and whether a counterpart
# was checked at all. `other` is the other side's package, NULL when there
# is none in this run. The client reports the pair. `exceptions` lists
# packages without a counterpart and pairs named differently. Returns
# the problems as sentences. Report only.
check_package_names <- function(pkg, other, package_rules) {
  rules <- package_rules$package
  exceptions <- rules$exceptions
  no_counterpart <- unlist(exceptions[[paste0(pkg$side, "_only")]])
  listed_pairs <- Filter(function(p) identical(p[[pkg$side]], pkg$name), exceptions$pairs)
  template <- function(side, name) sub("<name>", name, rules[[side]], fixed = TRUE)

  problems <- character(0)
  if (!grepl(sprintf("^%s$", template(pkg$side, rules$name)), pkg$name, perl = TRUE) &&
      !pkg$name %in% no_counterpart && length(listed_pairs) == 0) {
    problems <- c(problems, sprintf("`%s` doesn't follow `%s`.", pkg$name, rules[[pkg$side]]))
  }
  if (is.null(other)) {
    if (!pkg$name %in% no_counterpart) {
      problems <- c(problems, sprintf("No paired package was checked, and `%s` isn't listed as %s-only.", pkg$name, pkg$side))
    }
    return(problems)
  }
  if (pkg$side != "client" || length(listed_pairs) > 0) {
    return(problems)
  }
  pattern <- sprintf("^%s$", template("server", sprintf("(%s)", rules$name)))
  expected <- template("client", sub(pattern, "\\1", other$name, perl = TRUE))
  if (!identical(pkg$name, expected)) {
    problems <- c(problems, sprintf("`%s` and `%s` aren't a pair: expected the client `%s`.", pkg$name, other$name, expected))
  }
  problems
}
