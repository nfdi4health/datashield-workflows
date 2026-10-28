# Renames the approved arguments (`renames`: fn, old, new) throughout one
# package directory: R code under R/ and tests/ by parse data
# (find_r_rename_edits(); `server_renames` for named server calls),
# roxygen comments and shared templates (man-roxygen/), plain comments,
# man/*.Rd, and the R chunks of vignettes and README.Rmd. An edited R file
# must still parse, else it is left as it was. Returns list(files =
# changed paths relative to `pkg_dir`, counts = edits per file, notes =
# things for a person).
apply_naming_to_package <- function(pkg_dir, renames, server_renames = NULL) {
  rel <- function(p) sub(paste0("^", gsub("([.])", "\\\\\\1", normalizePath(pkg_dir, "/")), "/"), "", normalizePath(p, "/"))
  listing <- function(dir, pattern, recursive = FALSE) list.files(file.path(pkg_dir, dir), pattern = pattern, full.names = TRUE, recursive = recursive)
  r_files <- c(listing("R", "\\.[Rr]$"), listing("tests", "\\.[Rr]$", TRUE), listing("vignettes", "\\.[Rr]$"))
  rd_files <- listing("man", "\\.Rd$")
  chunk_files <- c(listing("vignettes", "\\.(Rmd|qmd|rmd)$"), list.files(pkg_dir, "^README\\.(Rmd|qmd)$", full.names = TRUE))

  files <- character(0)
  counts <- integer(0)
  notes <- character(0)
  save <- function(path, file, lines, n) {
    if (n == 0 || identical(lines, file$lines)) {
      return()
    }
    write_lines_keep_eol(lines, file, path)
    files <<- c(files, rel(path))
    counts[[rel(path)]] <<- n
  }

  for (path in r_files) {
    file <- read_lines_keep_eol(path)
    found <- find_r_rename_edits(file$lines, renames, server_renames)
    if (is.null(found)) {
      notes <- c(notes, sprintf("%s does not parse; only calls in it were renamed, as text.", rel(path)))
      lines <- file$lines; n <- 0
      for (r in seq_len(nrow(renames))) {
        res <- rename_call_args_text(lines, renames$fn[r], renames$old[r], renames$new[r])
        lines <- res$lines; n <- n + res$done
      }
      save(path, file, lines, n)
      next
    }
    edited <- apply_token_edits(file$lines, found$edits)
    notes <- c(notes, sprintf("%s: %s", rel(path), c(found$notes, edited$skipped)))
    rox <- rename_in_roxygen(edited$lines, renames)
    comments <- rename_in_comments(rox$lines, renames)
    lines <- comments$lines
    if (is.null(tryCatch(parse(text = lines, keep.source = FALSE), error = function(e) NULL))) {
      notes <- c(notes, sprintf("%s: would not parse after renaming — left unchanged, rename by hand.", rel(path)))
      next
    }
    save(path, file, lines, edited$done + rox$done + comments$done)
  }
  tpl <- rename_in_templates(pkg_dir, renames)
  files <- c(files, tpl$files)
  counts <- c(counts, tpl$counts)
  notes <- c(notes, tpl$notes)
  for (path in rd_files) {
    file <- read_lines_keep_eol(path)
    res <- rename_in_rd(file$lines, renames)
    save(path, file, res$lines, res$done)
  }
  for (path in chunk_files) {
    file <- read_lines_keep_eol(path)
    res <- rename_in_chunks(file$lines, renames)
    save(path, file, res$lines, res$done)
  }
  list(files = files, counts = counts, notes = notes)
}
