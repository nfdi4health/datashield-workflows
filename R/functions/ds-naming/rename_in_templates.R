# Applies the renames (fn, old, new) to shared roxygen templates
# (man-roxygen/*.R, pulled into a function's block with @template): a
# template's `@param old` is renamed when every function using the
# template renames `old` to the same new name; otherwise it is left and
# reported (the functions would need different docs). Returns list(files,
# counts, notes), paths relative to `pkg_dir`.
rename_in_templates <- function(pkg_dir, renames) {
  out <- list(files = character(0), counts = integer(0), notes = character(0))
  templates <- list.files(file.path(pkg_dir, "man-roxygen"), pattern = "\\.[Rr]$", full.names = TRUE)
  if (length(templates) == 0 || nrow(renames) == 0) {
    return(out)
  }

  # which function's block uses which template
  users <- list()
  for (p in list.files(file.path(pkg_dir, "R"), pattern = "\\.[Rr]$", full.names = TRUE)) {
    lines <- readLines(p, warn = FALSE, encoding = "UTF-8")
    rox <- grepl("^\\s*#'", lines)
    defs <- grep("^\\s*`?[A-Za-z.][A-Za-z0-9._]*`?\\s*(<-|=)\\s*function\\b", lines)
    for (d in defs) {
      fn <- sub("^\\s*`?([A-Za-z.][A-Za-z0-9._]*)`?.*$", "\\1", lines[d])
      i <- d - 1
      while (i >= 1 && (rox[i] || !nzchar(trimws(lines[i])))) {
        i <- i - 1
      }
      block <- lines[which(rox[seq_len(d - 1)] & seq_len(d - 1) > i)]
      used <- sub("^\\s*#'\\s*@template\\s+(\\S+).*$", "\\1", grep("^\\s*#'\\s*@template\\s", block, value = TRUE))
      for (t in used) {
        users[[t]] <- c(users[[t]], fn)
      }
    }
  }

  for (path in templates) {
    name <- sub("\\.[Rr]$", "", basename(path))
    fns <- unique(users[[name]])
    if (length(fns) == 0) {
      next
    }
    file <- read_lines_keep_eol(path)
    lines <- file$lines
    params <- sub("^\\s*#'\\s*@param\\s+(\\S+).*$", "\\1", grep("^\\s*#'\\s*@param\\s", lines, value = TRUE))
    done <- 0
    for (p in unlist(strsplit(params, ","))) {
      r <- renames[renames$old == p & renames$fn %in% fns, ]
      if (nrow(r) == 0) {
        next
      }
      if (length(unique(r$new)) == 1 && all(fns %in% r$fn)) {
        at <- grep(paste0("^\\s*#'\\s*@param\\s+", gsub("([.])", "\\\\\\1", p), "(\\s|,|$)"), lines)
        lines[at] <- sub(paste0("(@param\\s+)", gsub("([.])", "\\\\\\1", p)), paste0("\\1", r$new[1]), lines[at])
        done <- done + length(at)
      } else {
        out$notes <- c(out$notes, sprintf("man-roxygen/%s: `%s` is renamed differently or not at all by the functions using this template (%s) — split the template or adjust by hand.",
                                          basename(path), p, paste(sprintf("%s: %s", fns, ifelse(fns %in% r$fn, r$new[match(fns, r$fn)], "kept")), collapse = ", ")))
      }
    }
    if (done > 0) {
      write_lines_keep_eol(lines, file, path)
      rel <- file.path("man-roxygen", basename(path))
      out$files <- c(out$files, rel)
      out$counts[[rel]] <- done
    }
  }
  out
}
