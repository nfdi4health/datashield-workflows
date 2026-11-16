# The papers of a PubMed efetch answer (XML text) as a data frame: pmid,
# pmcid ("" if none), title, abstract (sections as "Label: text").
parse_pubmed_xml <- function(xml) {
  doc <- xml2::read_xml(xml)
  articles <- xml2::xml_find_all(doc, "//PubmedArticle")
  text_of <- function(node, path) {
    found <- xml2::xml_find_first(node, path)
    if (inherits(found, "xml_missing")) "" else trimws(xml2::xml_text(found))
  }
  rows <- lapply(articles, function(a) {
    parts <- xml2::xml_find_all(a, ".//Abstract/AbstractText")
    labels <- xml2::xml_attr(parts, "Label")
    texts <- trimws(xml2::xml_text(parts))
    abstract <- paste(ifelse(is.na(labels) | labels == "", texts, paste0(labels, ": ", texts)), collapse = "\n")
    data.frame(
      pmid = text_of(a, ".//MedlineCitation/PMID"),
      pmcid = text_of(a, ".//PubmedData/ArticleIdList/ArticleId[@IdType='pmc']"),
      title = text_of(a, ".//ArticleTitle"),
      abstract = abstract
    )
  })
  if (length(rows) == 0) {
    return(data.frame(pmid = character(0), pmcid = character(0), title = character(0), abstract = character(0)))
  }
  do.call(rbind, rows)
}
