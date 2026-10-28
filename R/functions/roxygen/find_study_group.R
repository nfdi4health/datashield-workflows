# Finds the study group in datashield-example-env.yml whose
# compatible_packages lists one of `package_names` (the package itself,
# plus its dependencies for a utility package), or NULL if none does.
find_study_group <- function(example_env, package_names) {
  package_names <- package_names[!is.na(package_names)]
  if (is.null(example_env) || length(package_names) == 0) {
    return(NULL)
  }
  Find(function(grp) any(package_names %in% unlist(grp$compatible_packages)), example_env$study_groups)
}
