# Which of `function$roxygen$required_tags` in the package rules each
# user-facing function's roxygen block lacks. `param` means every argument
# but `...` is documented, or the block has @inheritParams. Returns the
# problems as sentences, one per function. Report only.
check_roxygen_tags <- function(pkg, package_rules) {
  required <- unlist(package_rules$`function`$roxygen$required_tags)
  problems <- character(0)
  for (d in pkg$defs) {
    if (!d$name %in% pkg$user_facing) {
      next
    }
    missing <- setdiff(setdiff(required, "param"), d$tags)
    undocumented <- setdiff(d$args, c(names(d$param_docs), "..."))
    if ("param" %in% required && length(undocumented) > 0 && !"inheritParams" %in% d$tags) {
      missing <- c(missing, sprintf("param (%s)", paste(undocumented, collapse = ", ")))
    }
    if (length(missing) > 0) {
      problems <- c(problems, sprintf("`%s`: missing %s.", d$name, paste(missing, collapse = ", ")))
    }
  }
  problems
}
