# One section of the literature watch's report: the numbers of
# summarise_method_sources() for the given entries. `entry` is the query's
# own entry (its search and period), NULL for all queries together.
format_watch_section <- function(title, entry, entries, top = 20) {
  pct <- function(x) if (is.na(x)) "–" else sprintf("%.0f%%", 100 * x)
  found <- watch_entry_methods(entries)
  s <- summarise_method_sources(found, attr(found, "papers"), top)
  lines <- c(sprintf("## %s", title), "")
  if (!is.null(entry)) {
    lines <- c(lines, sprintf("PubMed: `%s`, open access, published %s to %s. Found %d, with a methods section %d, compared **%d**.",
      entry$pubmed, entry$from, entry$to, entry$found, entry$with_methods_section, entry$compared), "")
    if (isTRUE(entry$stopped)) {
      lines <- c(lines, sprintf("_Stopped at the subscription's usage limit after %d of %d papers; the numbers cover those._",
        entry$compared, entry$with_methods_section), "")
    }
  } else {
    lines <- c(lines, sprintf("Papers compared, each counted once: **%d**.", s$papers), "")
  }
  if (s$papers == 0) return(c(lines, "No paper to compare."))
  lines <- c(lines,
    "| Methods named in the methods sections | Also named in the abstract |",
    "|---|---|",
    sprintf("| all (%d) | %s |", s$methods_in_sections, pct(s$share_in_abstract)),
    sprintf("| main analyses | %s |", pct(s$share_main)),
    sprintf("| secondary methods (imputation, weighting, sensitivity, ...) | %s |", pct(s$share_secondary)),
    "",
    sprintf("Named only in an abstract: %d.", s$abstract_only))
  if (nrow(s$only_in_section) > 0) {
    lines <- c(lines, "", "**Most often only in the methods section:**", "",
      "| Method | Papers |", "|---|---|",
      sprintf("| %s | %d |", s$only_in_section$method, s$only_in_section$papers))
  }
  lines
}
