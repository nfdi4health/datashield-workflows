# A package's License field against `package$allowed_licences` in the
# package rules. Returns the problem as a sentence, or nothing. Report only.
check_package_licence <- function(pkg, package_rules) {
  allowed <- unlist(package_rules$package$allowed_licences)
  licence <- trimws(unname(read.dcf(file.path(pkg$dir, "DESCRIPTION"), fields = "License")[1, 1]))
  if (is.na(licence)) {
    return("No License field in `DESCRIPTION`.")
  }
  if (!licence %in% allowed) {
    return(sprintf("Licence `%s` isn't one of: %s.", licence, paste(sprintf("`%s`", allowed), collapse = ", ")))
  }
  character(0)
}
