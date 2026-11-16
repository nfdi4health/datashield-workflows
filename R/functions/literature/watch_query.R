# One query of the literature watch: open-access papers of the last
# settings$pilot$months from PubMed, their abstracts and methods sections
# from PMC, and Claude's list of the methods each names. Returns the
# query's entry for the data file (watch_entry_methods() reads it back),
# with `stopped` TRUE when the subscription's usage limit ended the calls.
# Only IDs, titles and method names are kept, never the papers' text.
watch_query <- function(query, settings, claude, today = Sys.Date()) {
  mindate <- seq(today, by = sprintf("-%d months", settings$pilot$months %||% 12), length.out = 2)[2]
  term <- sprintf('(%s) AND "pubmed pmc open access"[filter]', query$pubmed)
  pmids <- search_pubmed(term, format(mindate, "%Y/%m/%d"), format(today, "%Y/%m/%d"), settings$pilot$papers %||% 100, settings)
  message(sprintf("%s: %d open-access papers found (%s to %s).", query$name, length(pmids), mindate, today))
  entry <- list(pubmed = query$pubmed, from = as.character(mindate), to = as.character(today),
    found = length(pmids), with_methods_section = 0L, compared = 0L, stopped = FALSE, papers = list())
  if (length(pmids) == 0) return(entry)
  papers <- fetch_pubmed_abstracts(pmids, settings)
  papers <- papers[nzchar(papers$pmcid) & nzchar(papers$abstract), ]
  if (nrow(papers) > 0) {
    sections <- fetch_methods_sections(papers$pmcid, settings)
    papers$methods <- unname(sections[papers$pmcid])
    papers <- papers[!is.na(papers$methods) & nzchar(papers$methods), ]
  }
  entry$with_methods_section <- nrow(papers)
  message(sprintf("%s: %d papers with an abstract and a methods section.", query$name, nrow(papers)))
  if (nrow(papers) == 0) return(entry)
  found <- ask_claude_for_method_sources(claude, papers, settings)
  answered <- attr(found, "answered")
  entry$compared <- length(answered)
  entry$stopped <- isTRUE(attr(found, "stopped"))
  entry$papers <- lapply(answered, function(id) {
    rows <- found[found$id == id, ]
    list(pmid = id, pmcid = papers$pmcid[papers$pmid == id][1], title = papers$title[papers$pmid == id][1],
      methods = lapply(seq_len(nrow(rows)), function(i) {
        m <- as.list(rows[i, c("name", "variant", "role", "in_abstract", "in_methods_section")])
        if (!nzchar(m$variant)) m$variant <- NULL  # the plain method: no key in the data file
        m
      }))
  })
  entry
}
