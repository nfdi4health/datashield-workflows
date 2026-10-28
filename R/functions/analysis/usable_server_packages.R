# The server packages the analysis can use: those installed on EVERY
# study. Returns a data frame (package, version) plus notes (wording from
# `texts$notes`): a package missing on some studies isn't usable for a
# pooled analysis, and differing versions are tested with the lowest one
# (the version every study has at least).
usable_server_packages <- function(plan, texts) {
  per_study <- lapply(plan$studies, function(s) vapply(s$packages, as.character, character(1)))
  servers <- vapply(plan$studies, function(s) s$server, character(1))
  notes <- character(0)
  rows <- list()

  for (p in unique(unlist(lapply(per_study, names)))) {
    versions <- vapply(per_study, function(x) {
      if (p %in% names(x)) {
        return(x[[p]])
      }
      NA_character_
    }, character(1))
    if (anyNA(versions)) {
      notes <- c(notes, fill_template(texts$notes$package_missing_on_studies, list(
        PACKAGE = p, STUDIES = paste(sprintf("`%s`", servers[is.na(versions)]), collapse = ", ")
      )))
      next
    }
    version <- versions[[1]]
    if (length(unique(versions)) > 1) {
      # Versions that aren't plain numbers (e.g. "6.3.2-dev") can't be
      # compared; then the first study's version is used.
      parsed <- numeric_version(versions, strict = FALSE)
      version <- if (anyNA(parsed)) {
        versions[[1]]
      } else {
        as.character(min(parsed))
      }
      notes <- c(notes, fill_template(texts$notes$package_versions_differ, list(
        PACKAGE = p, VERSIONS = paste(unique(versions), collapse = ", "), LOWEST = version
      )))
    }
    rows[[length(rows) + 1]] <- data.frame(package = p, version = version)
  }

  packages <- data.frame(package = character(0), version = character(0))
  if (length(rows) > 0) {
    packages <- do.call(rbind, rows)
  }
  list(packages = packages, notes = notes)
}
