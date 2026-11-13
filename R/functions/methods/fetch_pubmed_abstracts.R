# Title, abstract and PMC ID (where PubMed lists one) of PubMed papers
# (efetch), in batches of 200. A structured abstract keeps its section
# labels ("Methods: ..."). Returns a data frame: pmid, pmcid ("" if none),
# title, abstract.
fetch_pubmed_abstracts <- function(pmids, settings) {
  rows <- list()
  for (batch in split(pmids, ceiling(seq_along(pmids) / 200))) {
    resp <- ncbi_request("efetch.fcgi", list(db = "pubmed", id = paste(batch, collapse = ","), retmode = "xml"), settings)
    rows <- c(rows, list(parse_pubmed_xml(httr2::resp_body_string(resp))))
  }
  if (length(rows) == 0) {
    return(data.frame(pmid = character(0), pmcid = character(0), title = character(0), abstract = character(0)))
  }
  do.call(rbind, rows)
}
