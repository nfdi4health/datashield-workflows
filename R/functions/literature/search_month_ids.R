# All PubMed IDs a search finds among papers published in one month
# (esearch, publication date), page by page; with their number as PubMed
# reports it. Returns list(ids, count).
search_month_ids <- function(search, month, settings, page = 5000) {
  range <- month_range(month)
  ids <- character(0)
  count <- NA_integer_
  repeat {
    resp <- ncbi_request("esearch.fcgi", list(
      db = "pubmed", term = search, retmode = "json", retmax = page, retstart = length(ids),
      datetype = "pdat", mindate = range[1], maxdate = range[2]
    ), settings)
    found <- httr2::resp_body_json(resp)$esearchresult
    count <- as.integer(found$count %||% 0)
    batch <- as.character(unlist(found$idlist))
    ids <- c(ids, batch)
    if (length(batch) == 0 || length(ids) >= count) break
  }
  list(ids = unique(ids), count = count)
}
