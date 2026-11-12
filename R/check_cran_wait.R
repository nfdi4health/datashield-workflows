#!/usr/bin/env Rscript
# The waiting-time check of cran-wait-check.yml: fails while the last CRAN
# submission of the package in the current directory is less than MIN_DAYS
# ago, unless OVERRIDE is "true" (a label on the pull request). Reads the
# package's publication date from crandb and the cran-* tags of this
# repository (fetched by the workflow). Writes the verdict to the step
# summary.
functions_dir <- if (dir.exists("R/functions/cran")) "R/functions" else ".shared-workflows/R/functions"
for (f in list.files(file.path(functions_dir, "cran"), pattern = "\\.R$", full.names = TRUE)) source(f)

package <- read.dcf("DESCRIPTION", fields = "Package")[1, 1]
cran <- tryCatch({
  resp <- httr2::request(sprintf("https://crandb.r-pkg.org/%s", package)) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) == 200) httr2::resp_body_json(resp)[["Date/Publication"]] else NULL
}, error = function(e) stop(sprintf("Could not reach crandb: %s", conditionMessage(e)), call. = FALSE))
prefix <- Sys.getenv("TAG_PREFIX", "cran-")
lines <- system2("git", c("for-each-ref", sprintf("refs/tags/%s*", prefix), "--format=%(refname:short) %(creatordate:iso-strict)"), stdout = TRUE)
tags <- setNames(sub("^\\S+ ", "", lines), sub(" .*$", "", lines))

verdict <- cran_wait_verdict(last_cran_submission(cran, tags), Sys.Date(), as.integer(Sys.getenv("MIN_DAYS", "60")),
  identical(Sys.getenv("OVERRIDE"), "true"))
message(verdict$message)
summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) write(paste("### CRAN waiting time\n\n", verdict$message), summary_file, append = TRUE)
if (!verdict$ok) quit(status = 1)
