# What Claude reads of each paper, fetched from PubMed and PMC: the
# abstract (PubMed) and the methods section (PMC, open access), with the
# paper's PMC ID, DOI, journal and title. Returns fetch_pubmed_abstracts()'s
# data frame plus a column `methods` ("" where PMC has no methods section).
fetch_paper_texts <- function(pmids, settings) {
  papers <- fetch_pubmed_abstracts(pmids, settings)
  papers$methods <- rep("", nrow(papers))
  with_pmc <- nzchar(papers$pmcid)
  if (any(with_pmc)) {
    sections <- fetch_methods_sections(papers$pmcid[with_pmc], settings)
    found <- unname(sections[papers$pmcid[with_pmc]])
    papers$methods[with_pmc] <- ifelse(is.na(found), "", found)
  }
  papers
}
