# Which of `package$required_files` in the package rules (files or
# folders) a package lacks. Returns the problem as a sentence, or nothing.
# Report only.
check_required_files <- function(pkg, package_rules) {
  required <- unlist(package_rules$package$required_files)
  missing <- required[!file.exists(file.path(pkg$dir, required))]
  if (length(missing) == 0) {
    return(character(0))
  }
  sprintf("Missing: %s.", paste(sprintf("`%s`", missing), collapse = ", "))
}
