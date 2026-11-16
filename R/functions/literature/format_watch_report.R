# The month's report of the literature watch (markdown), built from the
# data file alone, so a re-run of one query renders the others unchanged:
# all queries together when there are several, then one section per query.
# `missing` names queries of the config this month's data lacks (e.g. not
# reached before a usage limit).
format_watch_report <- function(data, top = 20, missing = character(0)) {
  queries <- data$queries %||% list()
  lines <- c(sprintf("# Literature watch %s", data$month), "")
  if (identical(data$mode, "pilot")) {
    lines <- c(lines, "Pilot: are the methods DataSHIELD may lack named in the abstracts, or only in the methods sections?", "")
  }
  if (length(queries) > 1) {
    lines <- c(lines, format_watch_section("All queries", NULL, queries, top), "")
  }
  for (name in names(queries)) {
    lines <- c(lines, format_watch_section(name, queries[[name]], list(queries[[name]]), top), "")
  }
  if (length(missing) > 0) {
    lines <- c(lines, sprintf("_Not run this month: %s._", paste(missing, collapse = ", ")), "")
  }
  c(lines, "_A high share for secondary methods means abstracts are enough; a low one means the methods sections (open access only) add what DataSHIELD most likely lacks. Names aren't merged into synonyms yet._")
}
