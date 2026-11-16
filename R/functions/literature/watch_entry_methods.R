# The methods of one or more entries of the literature watch's data file
# as the data frame summarise_method_sources() takes (id, name, variant,
# role, in_abstract, in_methods_section; variant "" for the plain method). A paper found by several queries
# counts once.
watch_entry_methods <- function(entries) {
  papers <- unlist(lapply(entries, function(e) e$papers %||% list()), recursive = FALSE)
  papers <- papers[!duplicated(vapply(papers, function(p) as.character(p$pmid), ""))]
  rows <- lapply(papers, function(p) lapply(p$methods %||% list(), function(m)
    data.frame(id = as.character(p$pmid), name = m$name, variant = m$variant %||% "", role = m$role,
      in_abstract = isTRUE(m$in_abstract), in_methods_section = isTRUE(m$in_methods_section))))
  rows <- unlist(rows, recursive = FALSE)
  found <- if (length(rows) == 0) {
    data.frame(id = character(0), name = character(0), variant = character(0), role = character(0),
      in_abstract = logical(0), in_methods_section = logical(0))
  } else {
    do.call(rbind, rows)
  }
  attr(found, "papers") <- length(papers)
  found
}
