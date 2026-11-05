# Whether a package declares a licence (`package$licence_required` in the
# package rules); which one is up to the package. Returns the problem as
# a sentence, or nothing. Report only.
check_package_licence <- function(pkg, package_rules) {
  licence <- trimws(unname(read.dcf(file.path(pkg$dir, "DESCRIPTION"), fields = "License")[1, 1]))
  if (isTRUE(package_rules$package$licence_required) && (is.na(licence) || !nzchar(licence))) {
    return("No License field in `DESCRIPTION`.")
  }
  character(0)
}
