# Regenerates the .Rd files of the R files the bot changed, so man/ stays
# in step with the roxygen blocks (found on dsAnalysis #39/#43: merging the
# suggestions left man/ stale). Only for packages that keep roxygen-made
# man pages (a man/ folder, and RoxygenNote in DESCRIPTION, or
# Config/roxygen2/version, which roxygen2 8 writes instead). roxygen2 runs
# in a separate R process without the Claude and GitHub tokens
# (credential_variables()), with only the rd roclet and the package's R
# files sourced (roxygen2::load_source), so the package's dependencies need
# not be installed. Of what it writes, only the pages whose "Please edit
# documentation in" line names one of `r_files` are kept; every other
# change (pages of untouched functions, which an installed roxygen2 of
# another version may write differently, DESCRIPTION's RoxygenNote) is
# put back. Returns the kept .Rd paths, for updated_files.txt.
regenerate_man_pages <- function(r_files, dir = ".") {
  r_files <- unique(r_files[grepl("^R/.*\\.[Rr]$", r_files)])
  desc <- file.path(dir, "DESCRIPTION")
  man <- file.path(dir, "man")
  if (length(r_files) == 0 || !dir.exists(man) || !file.exists(desc) ||
      !any(grepl("^(RoxygenNote|Config/roxygen2/version):", readLines(desc, warn = FALSE)))) {
    return(character(0))
  }
  if (!requireNamespace("roxygen2", quietly = TRUE)) {
    message("roxygen2 isn't installed: man/ is not regenerated.")
    return(character(0))
  }

  snapshot <- function() {
    files <- c(list.files(man, pattern = "\\.Rd$", full.names = TRUE), desc)
    stats::setNames(lapply(files, function(f) readLines(f, warn = FALSE)), files)
  }
  before <- snapshot()

  script <- tempfile(fileext = ".R")
  writeLines(sprintf("roxygen2::roxygenise(%s, roclets = \"rd\", load_code = roxygen2::load_source)",
                     deparse(normalizePath(dir))), script)
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
    stdout = TRUE, stderr = TRUE, env = paste0(credential_variables(), "=")))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    message("Regenerating man/ failed; the .Rd files stay as they were:\n", paste(utils::tail(out, 15), collapse = "\n"))
    for (f in names(before)) writeLines(before[[f]], f)
    return(character(0))
  }

  after <- snapshot()
  sources_of <- function(lines) {
    header <- lines[seq_len(min(length(lines), 6))]
    header <- header[grepl("^%", header)]
    text <- paste(sub("^%\\s*", "", header), collapse = " ")
    text <- sub(".*Please edit documentation in\\s*", "", text)
    trimws(unlist(strsplit(text, "[,[:space:]]+")))
  }
  kept <- character(0)
  for (f in union(names(before), names(after))) {
    old <- before[[f]]
    new <- after[[f]]
    if (identical(old, new)) next
    ours <- !identical(f, desc) && !is.null(new) && any(sources_of(new) %in% r_files)
    if (ours) {
      kept <- c(kept, f)
    } else if (is.null(old)) {
      unlink(f)
    } else {
      writeLines(old, f)
    }
  }
  kept <- substring(kept, nchar(file.path(dir, "")) + 1)   # relative to `dir`, e.g. man/f.Rd
  if (length(kept) > 0) message(sprintf("Regenerated %s.", paste(kept, collapse = ", ")))
  kept
}
