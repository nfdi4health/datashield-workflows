# The candidate pull request's description: what to do, the new
# candidates (format_candidate_section()), the deferred ones with their
# own boxes, and those already tracked by a hub issue (no boxes).
format_candidates_body <- function(new, deferred, tracked_rows, tracked, vocab, research, month) {
  label <- function(row) {
    name <- method_label(vocab, row$method)
    if (nzchar(row$variant)) sprintf("%s: %s", name, method_label(vocab, row$method, row$variant)) else name
  }
  out <- c(sprintf("The literature watch's candidates for %s: methods health research uses often that DataSHIELD lacks.", month), "",
    "Tick **exactly one** box per candidate (the check stays red until every candidate has one), then merge:",
    "- **Open an issue**: an idea issue is opened here, with this brief.",
    "- **Not now**: listed again next month under \"Deferred\".",
    "- **Don't suggest again**: left out until its papers double.", "",
    "The research is Claude's, with web search: a starting point, not a verdict.", "")
  for (i in seq_len(nrow(new))) out <- c(out, format_candidate_section(i, new[i, ], vocab, research[[new$key[i]]]))
  if (nrow(deferred) > 0) {
    out <- c(out, "## Deferred", "")
    for (i in seq_len(nrow(deferred))) {
      row <- deferred[i, ]
      out <- c(out, sprintf("**%s**: %.0f%% of papers (%d), trend %s.", label(row), 100 * row$share, row$papers, row$trend), "",
        candidate_boxes(row$key), "")
    }
  }
  if (nrow(tracked_rows) > 0) {
    out <- c(out, "## Already tracked", "",
      vapply(seq_len(nrow(tracked_rows)), function(i) {
        row <- tracked_rows[i, ]
        sprintf("- %s: %.0f%% of papers (%d), trend %s%s", label(row), 100 * row$share, row$papers, row$trend,
          if (!is.null(tracked[[row$key]])) sprintf(", #%s", tracked[[row$key]]) else "")
      }, ""), "")
  }
  out
}
