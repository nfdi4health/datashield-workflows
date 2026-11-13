# The pilot's report (markdown): the numbers of summarise_method_sources()
# and what they mean for choosing abstracts, methods sections, or both.
format_pilot_report <- function(s, query_name, period) {
  pct <- function(x) if (is.na(x)) "–" else sprintf("%.0f%%", 100 * x)
  lines <- c(
    "## Researcher pilot: abstract or methods section?",
    "",
    sprintf("Query **%s**, papers published %s, open access with a methods section: **%d** papers compared.", query_name, period, s$papers),
    "",
    "| Methods named in the methods sections | Also named in the abstract |",
    "|---|---|",
    sprintf("| all (%d) | %s |", s$methods_in_sections, pct(s$share_in_abstract)),
    sprintf("| main analyses | %s |", pct(s$share_main)),
    sprintf("| secondary methods (imputation, weighting, sensitivity, ...) | %s |", pct(s$share_secondary)),
    "",
    sprintf("Named only in an abstract: %d.", s$abstract_only),
    ""
  )
  if (nrow(s$only_in_section) > 0) {
    lines <- c(lines, "**Most often only in the methods section:**", "",
      "| Method | Papers |", "|---|---|",
      sprintf("| %s | %d |", s$only_in_section$method, s$only_in_section$papers), "")
  }
  c(lines,
    "_A high share for secondary methods means abstracts are enough; a low one means the methods sections (open access only) add what DataSHIELD most likely lacks. Names aren't merged into synonyms yet._")
}
