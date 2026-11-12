#!/usr/bin/env Rscript
# Submits the built package (TARBALL) to CRAN for cran-submit.yml, with
# cran-comments.md as the note to the reviewers and the maintainer (cre)
# from DESCRIPTION. DRY_RUN "true" shows what would be sent and stops.
# Afterwards CRAN emails the maintainer, who confirms the submission.
functions_dir <- if (dir.exists("R/functions/cran")) "R/functions" else ".shared-workflows/R/functions"
for (f in list.files(file.path(functions_dir, "cran"), pattern = "\\.R$", full.names = TRUE)) source(f)

tarball <- Sys.getenv("TARBALL")
if (!file.exists(tarball)) stop(sprintf("No built package at '%s'.", tarball), call. = FALSE)
if (!file.exists("cran-comments.md")) {
  stop("cran-comments.md is missing: CRAN's reviewers expect the check results and notes explained there.", call. = FALSE)
}
comments <- paste(readLines("cran-comments.md", warn = FALSE), collapse = "\n")
m <- desc::desc("DESCRIPTION")$get_maintainer()
maintainer <- list(name = trimws(sub("<.*$", "", m)), email = sub("^.*<([^>]+)>.*$", "\\1", m))
message(sprintf("Package: %s\nMaintainer: %s <%s>\nComments:\n%s", basename(tarball), maintainer$name, maintainer$email, comments))
if (identical(Sys.getenv("DRY_RUN", "true"), "true")) {
  message("Dry run: nothing was sent to CRAN.")
  quit(save = "no")
}
id <- upload_to_cran(tarball, maintainer, comments)
message(sprintf("Submitted to CRAN (submission %s). %s now gets an email from CRAN: the submission is only reviewed once it is confirmed there.", id, maintainer$email))
