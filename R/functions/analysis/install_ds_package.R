# Installs a DataSHIELD package at a given version and returns what was
# installed: list(package, requested, installed, ref, note). A package
# already installed at that version (a cached or preinstalled library) is
# kept as it is. Most DataSHIELD packages are only on GitHub, so the
# sources are tried in this order (dev-notes/analysis-suggest.md,
# "Package versions"):
#   1. CRAN (incl. archive), if the catalogue lists a CRAN link;
#   2. a GitHub tag "v<version>", then "<version>";
#   3. the GitHub default branch — its version is then compared.
# A version that doesn't match, or no install at all, becomes a note for
# the report (wording from `texts$notes`); the run goes on with what is
# installed.
install_ds_package <- function(package, version, catalogue, texts) {
  installed_version <- function() {
    tryCatch(as.character(utils::packageVersion(package)), error = function(e) NA_character_)
  }
  if (identical(installed_version(), version)) {
    return(list(package = package, requested = version, installed = version, ref = "already installed", note = NULL))
  }

  entry <- catalogue[[package]]
  repo <- if (!is.null(entry) && nzchar(entry$github)) {
    sub("^https?://github.com/", "", entry$github)
  } else {
    NA_character_
  }
  refs <- character(0)
  if (is.null(entry) || nzchar(entry$cran)) {
    refs <- c(refs, sprintf("%s@%s", package, version))
  }
  if (!is.na(repo)) {
    refs <- c(refs, sprintf("%s@v%s", repo, version), sprintf("%s@%s", repo, version), repo)
  }

  for (ref in refs) {
    ok <- tryCatch({
      pak::pkg_install(ref, ask = FALSE, upgrade = FALSE)
      TRUE
    }, error = function(e) {
      message(sprintf("Installing %s from %s failed: %s", package, ref, conditionMessage(e)))
      FALSE
    })
    if (!ok) {
      next
    }
    got <- installed_version()
    note <- if (!identical(got, version)) {
      fill_template(texts$notes$version_not_found, list(PACKAGE = package, VERSION = version, INSTALLED = got, REF = ref))
    }
    return(list(package = package, requested = version, installed = got, ref = ref, note = note))
  }

  list(
    package = package, requested = version, installed = NA_character_, ref = NA_character_,
    note = fill_template(texts$notes$not_installable, list(PACKAGE = package, VERSION = version))
  )
}
