# Removes two headings the starter text of earlier versions wrote around
# the generated block, which the block now brings itself or no longer
# needs — only in exactly that shape, so nothing written by hand goes:
# "## Overview" directly followed by the overview block (the block starts
# with "## All workflows" now), and "## Workflows" with nothing below it
# (the per-workflow diagrams it introduced are gone). `lines` is the
# README; returns it, cleaned.
drop_old_starter_headings <- function(lines) {
  nonblank <- function(from, by) {
    i <- from
    while (i >= 1 && i <= length(lines) && !nzchar(trimws(lines[i]))) {
      i <- i + by
    }
    i
  }

  overview <- which(lines == "## Overview")
  for (i in rev(overview)) {
    nxt <- nonblank(i + 1, 1)
    if (nxt <= length(lines) && lines[nxt] == "<!-- workflow-graphs:overview:start -->") {
      lines <- lines[-seq(i, nxt - 1)]
    }
  }

  workflows <- which(lines == "## Workflows")
  for (i in rev(workflows)) {
    if (nonblank(i + 1, 1) > length(lines)) {
      start <- nonblank(i - 1, -1) + 1  # also the blank lines before it
      lines <- lines[seq_len(start - 1)]
    }
  }
  lines
}
