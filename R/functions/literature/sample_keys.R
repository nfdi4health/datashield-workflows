# Each paper's key in a field's random order: a hash of field and PubMed
# ID. Sorting a month's papers by key gives the same order on every run,
# and a paper that arrives late takes its place in it without changing the
# others' keys; the first `target` papers in that order are the field's
# sample of the month.
sample_keys <- function(field_name, pmids) {
  hash_keys(paste0(field_name, ":", pmids), 12)
}
