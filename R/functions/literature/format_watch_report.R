# The literature watch's report (markdown), built from the data alone: the
# round and its progress per field, all fields together (each paper once),
# one section per field, and the searches in use. Shares per year, never
# counts (the number of papers grows every year).
format_watch_report <- function(reg, state, fields, queries, months, progress, settings, today) {
  r <- settings$report
  target <- settings$sampling$target_per_month %||% 25
  years <- sort(unique(substr(months, 1, 4)))
  recent <- utils::head(months, 12 * (r$share_years %||% 3))
  complete <- all(progress$months_complete == progress$months)
  by_field <- lapply(fields, function(f) field_papers(reg, state, f$name, queries[[f$name]], months))
  names(by_field) <- vapply(fields, function(f) f$name, "")
  all_papers <- unlist(unname(by_field), recursive = FALSE)
  all_papers <- all_papers[!duplicated(names(all_papers))]
  lines <- c("# Literature watch", "",
    sprintf("Updated %s. Round: %d papers per field and publication month, %s to %s%s.", today, target,
      utils::tail(months, 1), months[1], if (complete) " (**complete**)" else ""), "",
    "Which statistical methods epidemiological research uses, from a random sample of open-access research articles in PubMed and PMC per field and month (no reviews). Claude lists each paper's methods from its abstract and methods section; only IDs, titles and the methods are stored.", "",
    "## Progress", "",
    "| Field | Months complete | Papers read |", "|---|---|---|",
    sprintf("| %s | %d / %d | %d / %d |", progress$field, progress$months_complete, progress$months, progress$papers_read, progress$sample_size),
    sprintf("| **all** | %d / %d | %d / %d |", sum(progress$months_complete), sum(progress$months), sum(progress$papers_read), sum(progress$sample_size)), "")
  lines <- c(lines, format_method_section("All fields", all_papers, years, recent, r$top %||% 20, r$chart_methods %||% 5, r$min_variant_papers %||% 2))
  for (f in names(by_field)) {
    lines <- c(lines, format_method_section(f, by_field[[f]], years, recent, 10, 0, r$min_variant_papers %||% 2))
  }
  searches <- vapply(fields, field_search, "", settings = settings)
  c(lines, "## Searches", "",
    "| Field | Version | Search |", "|---|---|---|",
    sprintf("| %s | `%s` | `%s` |", names(by_field), unlist(queries[names(by_field)]), gsub("|", "\\|", searches, fixed = TRUE)), "",
    "_Notes: shares are per year of publication; all fields dip in 2022-2023, most likely NLM's switch to automated MeSH indexing, so read changes around those years with care. Method names aren't merged into synonyms yet (\"t-test\" and \"Student's t-test\" are counted apart); that comes with the vocabulary step._")
}
