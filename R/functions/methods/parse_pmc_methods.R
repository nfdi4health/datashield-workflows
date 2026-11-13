# The methods section of each article of a PMC efetch answer (JATS XML
# text), named by PMC ID: the top-level <sec> whose sec-type or title says
# methods (also "statistical analysis", "materials and methods"), its text
# cut to `max_chars`. "" where none.
parse_pmc_methods <- function(xml, max_chars = 6000) {
  doc <- xml2::read_xml(xml)
  articles <- xml2::xml_find_all(doc, "//article")
  ids <- vapply(articles, function(a) {
    id <- xml2::xml_find_first(a, ".//front//article-id[@pub-id-type='pmc' or @pub-id-type='pmcid']")
    if (inherits(id, "xml_missing")) "" else sub("^(PMC)?", "PMC", trimws(xml2::xml_text(id)))
  }, character(1))
  sections <- vapply(articles, function(a) {
    secs <- xml2::xml_find_all(a, "./body/sec")
    type <- tolower(xml2::xml_attr(secs, "sec-type"))
    title <- tolower(vapply(secs, function(s) {
      t <- xml2::xml_find_first(s, "./title")
      if (inherits(t, "xml_missing")) "" else xml2::xml_text(t)
    }, character(1)))
    hit <- (!is.na(type) & grepl("method", type)) | grepl("method|statistical analys", title)
    if (!any(hit)) {
      return("")
    }
    # Text nodes joined with spaces: xml_text() of a section runs its title
    # and paragraphs together.
    nodes <- unlist(lapply(secs[hit], function(s) xml2::xml_text(xml2::xml_find_all(s, ".//text()"))))
    text <- gsub("[[:space:]]+", " ", paste(nodes, collapse = " "))
    substr(trimws(text), 1, max_chars)
  }, character(1))
  stats::setNames(sections, ids)
}
