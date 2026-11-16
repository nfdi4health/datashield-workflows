# A paper's record for the register (read_register()): its IDs and
# metadata, the field that found it with its key and search fingerprint,
# who read it and when, and Claude's methods (`found`: the rows of
# ask_claude_for_method_sources() for this paper; NULL for a paper without
# an abstract or methods section, which is kept as read but not usable).
paper_record <- function(paper, month, field_name, key, query, reader, today, found = NULL) {
  methods <- list()
  if (!is.null(found)) {
    methods <- lapply(seq_len(nrow(found)), function(i) {
      m <- list(name = found$name[i], variant = found$variant[i], role = found$role[i],
        in_abstract = found$in_abstract[i], in_methods_section = found$in_methods_section[i])
      if (!nzchar(m$variant %||% "")) m$variant <- NULL
      m
    })
  }
  list(
    pmid = paper$pmid, pmcid = paper$pmcid %||% "", doi = paper$doi %||% "", journal = paper$journal %||% "",
    title = paper$title %||% "", month = month,
    found_by = stats::setNames(list(list(key = key, query = query)), field_name),
    read = list(reader = reader, date = as.character(today)),
    usable = !is.null(found),
    methods = methods
  )
}
