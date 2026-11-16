# One request to NCBI's E-utilities (PubMed and PMC, free): `endpoint` such
# as "esearch.fcgi", `params` the query. Throttled to the allowed rate (3
# requests a second, 10 with an API key in NCBI_API_KEY) and retried on
# temporary errors. Names this tool, as NCBI asks; no e-mail address is
# sent. Returns the httr2 response.
ncbi_request <- function(endpoint, params, settings) {
  key <- Sys.getenv("NCBI_API_KEY")
  rate <- if (nzchar(key)) 10 else settings$ncbi$rate_per_second %||% 3
  params$tool <- settings$ncbi$tool %||% "datashield-workflows"
  if (nzchar(key)) {
    params$api_key <- key
  }
  req <- httr2::request(paste0(settings$ncbi$base_url %||% "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/", endpoint))
  req <- httr2::req_body_form(req, !!!params)
  req <- httr2::req_throttle(req, capacity = rate, fill_time_s = 1, realm = "ncbi")
  req <- httr2::req_retry(req, max_tries = 4)
  httr2::req_perform(req)
}
