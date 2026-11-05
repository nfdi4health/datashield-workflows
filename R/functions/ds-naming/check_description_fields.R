# Which of `package$description$required_fields` in the package rules a
# package's DESCRIPTION lacks. What a field says is up to the package.
# Returns the problem as a sentence, or nothing. Report only.
check_description_fields <- function(pkg, package_rules) {
  required <- unlist(package_rules$package$description$required_fields)
  values <- read.dcf(file.path(pkg$dir, "DESCRIPTION"), fields = required)[1, ]
  missing <- required[is.na(values) | !nzchar(trimws(values))]
  if (length(missing) == 0) {
    return(character(0))
  }
  sprintf("Missing in `DESCRIPTION`: %s.", paste(sprintf("`%s`", missing), collapse = ", "))
}
