# Title, abstract, journal and PMC ID and DOI (where PubMed lists them) of
# PubMed papers (efetch), in batches of 200. A structured abstract keeps
# its section labels ("Methods: ..."). Returns parse_pubmed_xml()'s data
# frame.
fetch_pubmed_abstracts <- function(pmids, settings) {
  rows <- list()
  for (batch in split(pmids, ceiling(seq_along(pmids) / 200))) {
    resp <- ncbi_request("efetch.fcgi", list(db = "pubmed", id = paste(batch, collapse = ","), retmode = "xml"), settings)
    rows <- c(rows, list(parse_pubmed_xml(httr2::resp_body_string(resp))))
  }
  if (length(rows) == 0) {
    return(parse_pubmed_xml("<PubmedArticleSet/>"))
  }
  do.call(rbind, rows)
}
