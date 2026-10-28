#!/usr/bin/env Rscript
# Renames the arguments approved in the transformation file (written by
# check_ds_naming.R, statuses set by people) in the package (the caller)
# and, if checked out (SERVER_DIR), its server package: definitions, uses
# in the body, calls by name in R/, tests/, roxygen examples, man/*.Rd and
# vignette chunks, named server calls call("aliasDS", old = ...).
# Deterministic and idempotent: an entry whose argument is already renamed
# is only marked applied. Writes, per repository, the list of changed
# files and the PR description; the transformation file's applied entries
# get `status: applied` in the caller's PR.
# Design: dev-notes/datashield-naming/README.md.

library(purrr)

functions_dir <- if (dir.exists("R/functions/ds-naming")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "ds-naming")), pattern = "\\.R$", full.names = TRUE), source)

transformation_file <- Sys.getenv("TRANSFORMATION_FILE", ".github/ds-naming/transformations.yml")
server_dir <- Sys.getenv("SERVER_DIR")
package_side <- Sys.getenv("PACKAGE_SIDE", "client")
if (!file.exists(transformation_file)) {
  stop(sprintf("No transformation file at %s — run the naming check first.", transformation_file), call. = FALSE)
}

entries <- read_transformation_file(transformation_file)$entries
own <- read_ds_package(".", package_side)
server <- if (package_side == "client" && nzchar(server_dir) && dir.exists(server_dir)) {
  read_ds_package(server_dir, "server")
} else {
  NULL
}

own_sel <- approved_renames(entries, own)
server_sel <- if (!is.null(server)) {
  approved_renames(entries, server)
} else {
  NULL
}

# Named server calls in the client, call("meanDS", xvect = ...), follow the
# server's renames; DESCRIPTION maps method aliases to functions.
server_calls <- if (!is.null(server_sel) && nrow(server_sel$renames) > 0) {
  do.call(rbind, lapply(seq_len(nrow(server_sel$renames)), function(i) {
    r <- server_sel$renames[i, ]
    aliases <- unique(c(names(server$methods)[server$methods == r$fn], r$fn))
    data.frame(alias = aliases, old = r$old, new = r$new)
  }))
} else {
  NULL
}

# Lockstep: a renamed argument whose linked counterpart is not approved.
approved_ids <- c(own_sel$renames$id, server_sel$renames$id)
lockstep <- unlist(lapply(entries[intersect(approved_ids, names(entries))], function(e) {
  other <- Filter(function(l) l %in% names(entries) && !entries[[l]]$status %in% c("approved", "applied"), unlist(e$linked))
  if (length(other) > 0) {
    sprintf("`%s` is renamed, its counterpart `%s` is not (status %s).", e$id, other,
                                 vapply(other, function(l) entries[[l]]$status, character(1)))
  }
}))

describe <- function(pkg_name, sel, result) {
  if (is.null(sel)) {
    return(character(0))
  }
  lines <- c(sprintf("## %s", pkg_name), "")
  if (nrow(sel$renames) > 0) {
    lines <- c(lines, sprintf("- `%s()`: `%s` → `%s`", sel$renames$fn, sel$renames$old, sel$renames$new), "")
  } else {
    lines <- c(lines, "No renames.", "")
  }
  if (length(result$files) > 0) {
    lines <- c(lines, "Files changed (edits):", "", sprintf("- `%s` (%d)", names(result$counts), result$counts), "")
  }
  if (length(sel$done) > 0) {
    lines <- c(lines, sprintf("Already done, marked applied: %s", paste(sprintf("`%s`", sel$done), collapse = ", ")), "")
  }
  if (length(sel$conflicts) > 0) {
    lines <- c(lines, sprintf("**Not renamed — the function already has the new name:** %s", paste(sprintf("`%s`", sel$conflicts), collapse = ", ")), "")
  }
  if (length(sel$missing) > 0) {
    lines <- c(lines, sprintf("**Not found in the code:** %s", paste(sprintf("`%s`", sel$missing), collapse = ", ")), "")
  }
  if (length(result$notes) > 0) {
    lines <- c(lines, "**Check by hand:**", "", sprintf("- %s", result$notes), "")
  }
  lines
}
footer <- c(
  "## Before merging",
  "",
  "- This is a **breaking change**: code calling these functions with the old argument names stops working.",
  "- Run `devtools::document()`: the Rd files were edited directly so checks pass, roxygen should confirm them.",
  "- Prose in vignettes and descriptions is not changed; read the diff of the documentation."
)

own_result <- apply_naming_to_package(".", own_sel$renames, server_calls)
own_applied <- c(own_sel$renames$id, own_sel$done)
server_result <- NULL
if (!is.null(server)) {
  server_result <- apply_naming_to_package(server_dir, server_sel$renames)
  own_applied <- c(own_applied, server_sel$renames$id, server_sel$done)
}
if (length(own_applied) > 0) {
  mark_entries_applied(transformation_file, own_applied)
}

head_lines <- c("Renames the DataSHIELD arguments approved in the naming review.", "")
if (length(lockstep) > 0) {
  head_lines <- c(head_lines, "**Client and server out of step:**", "", sprintf("- %s", lockstep), "")
}
report <- c(head_lines, describe(own$name, own_sel, own_result))
if (!is.null(server)) {
  report <- c(report, sprintf("The server package %s gets its own PR.", server$name))
}
writeLines(c(report, "", footer), "naming_apply_report.md")

# The transformation file is proposed too once entries were marked applied.
updated <- own_result$files
if (length(own_applied) > 0) {
  updated <- c(updated, transformation_file)
}
writeLines(updated, "updated_files.txt")
if (!is.null(server)) {
  writeLines(c(head_lines, describe(server$name, server_sel, server_result), footer), "naming_apply_report_server.md")
  writeLines(server_result$files, "server_updated_files.txt")
}
summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) {
  write(readLines("naming_apply_report.md"), summary_file, append = TRUE)
}
message(paste(readLines("naming_apply_report.md"), collapse = "\n"))
