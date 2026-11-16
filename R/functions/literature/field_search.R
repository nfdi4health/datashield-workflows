# The complete PubMed search of a field: the study design and the filters
# of settings$search (the same for every field: epidemiologic studies,
# open access in PMC, no reviews) around the field's own part from the
# hub's config, in brackets so its ORs stay together.
field_search <- function(field, settings) {
  paste0(settings$search$design, " AND (", field$pubmed, ") AND ", settings$search$filters)
}
