# Replaces the lines between a start and an end marker line in a file
# (markers kept), or appends a new marked block at the end if the file has
# neither marker. Everything outside the block stays as the analyst wrote
# it. Creates the file if it doesn't exist.
# Returns "changed", "unchanged", or "damaged": a marker missing, doubled
# or out of order (e.g. a copied block). A damaged file is left alone —
# appending would add another block on every run — and the caller reports
# it.
update_marked_block <- function(path, start_marker, end_marker, content) {
  old <- if (file.exists(path)) {
    readLines(path, warn = FALSE)
  } else {
    character(0)
  }
  start <- which(old == start_marker)
  end <- which(old == end_marker)
  block <- c(start_marker, content, end_marker)

  if (length(start) == 0 && length(end) == 0) {
    # A new block at the end, after a blank line.
    new <- old
    if (length(old) > 0 && nzchar(old[length(old)])) {
      new <- c(new, "")
    }
    new <- c(new, block)
  } else if (length(start) == 1 && length(end) == 1 && end > start) {
    new <- c(old[seq_len(start - 1)], block, old[-seq_len(end)])
  } else {
    return("damaged")
  }
  if (identical(new, old)) {
    return("unchanged")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(new, path)
  "changed"
}
