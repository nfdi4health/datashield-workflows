# PubMed IDs for a query, newest first (esearch): papers published from
# `mindate` to `maxdate` (YYYY/MM/DD), at most `max`.
search_pubmed <- function(query, mindate, maxdate, max, settings) {
  resp <- ncbi_request("esearch.fcgi", list(
    db = "pubmed", term = query, retmode = "json", retmax = max, sort = "pub_date",
    datetype = "pdat", mindate = mindate, maxdate = maxdate
  ), settings)
  found <- httr2::resp_body_json(resp)$esearchresult
  as.character(unlist(found$idlist))
}
