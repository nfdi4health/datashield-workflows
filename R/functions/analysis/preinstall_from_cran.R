# Installs the wanted packages that are on CRAN (catalogue CRAN link) and
# not yet installed at their version in one pak call: one dependency
# resolution instead of one per package, which saves minutes with
# dsBase's dependencies. `wanted` is a named character vector
# (package -> version). If the batch fails, nothing is lost:
# install_ds_package() then tries each package on its own.
preinstall_from_cran <- function(wanted, catalogue) {
  on_cran <- names(wanted)[vapply(names(wanted), function(p) !is.null(catalogue[[p]]) && nzchar(catalogue[[p]]$cran), logical(1))]
  missing <- on_cran[vapply(on_cran, function(p) {
    !identical(tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_), wanted[[p]])
  }, logical(1))]
  if (length(missing) == 0) {
    return(invisible(character(0)))
  }
  refs <- sprintf("%s@%s", missing, wanted[missing])
  tryCatch(pak::pkg_install(refs, ask = FALSE, upgrade = FALSE), error = function(e) {
    message(sprintf("Installing %s together failed, trying one by one: %s", paste(refs, collapse = ", "), conditionMessage(e)))
  })
  invisible(refs)
}
