# Sets `status: applied` for the given entry ids in the transformation
# file, editing only those lines, so the file keeps its layout and any
# comments people added.
mark_entries_applied <- function(path, ids) {
  file <- read_lines_keep_eol(path)
  lines <- file$lines
  current <- ""
  for (i in seq_along(lines)) {
    if (grepl("^\\s*- id:", lines[i])) {
      current <- trimws(gsub("^['\"]|['\"]$", "", trimws(sub("^\\s*- id:", "", lines[i]))))
    }
    if (current %in% ids && grepl("^\\s*status:\\s*approved\\s*$", lines[i])) {
      lines[i] <- sub("approved", "applied", lines[i])
    }
  }
  write_lines_keep_eol(lines, file, path)
}
