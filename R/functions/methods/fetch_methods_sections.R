# The methods sections of open-access papers in PMC (efetch, JATS XML), in
# batches of 50: named by PMC ID ("PMC1234567"), "" where none was found
# (or the paper's full text isn't open access).
fetch_methods_sections <- function(pmcids, settings) {
  out <- character(0)
  for (batch in split(pmcids, ceiling(seq_along(pmcids) / 50))) {
    resp <- ncbi_request("efetch.fcgi", list(db = "pmc", id = paste(sub("^PMC", "", batch), collapse = ","), retmode = "xml"), settings)
    out <- c(out, parse_pmc_methods(httr2::resp_body_string(resp), settings$pilot$max_section_chars %||% 6000))
  }
  out
}
