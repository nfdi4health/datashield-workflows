# The paper register of the literature watch's data folder, as an
# environment so the run can update it in place: `papers`, a list of
# records by PubMed ID (each paper read by Claude once, whichever field or
# month found it), and `dirty`, the months whose file must be written
# again. A record: pmid, pmcid, doi, journal, title, month, found_by (per
# field its key in the field's random order and the fingerprint of the
# search that found it), read (reader fingerprint and date), usable (FALSE
# without an abstract or methods section) and methods (Claude's answer).
# Never the papers' text.
read_register <- function(dir) {
  reg <- new.env()
  reg$papers <- list()
  reg$dirty <- character(0)
  files <- list.files(file.path(dir, "papers"), pattern = "\\.jsonl$", recursive = TRUE, full.names = TRUE)
  for (f in files) {
    for (line in readLines(f, warn = FALSE, encoding = "UTF-8")) {
      if (!nzchar(trimws(line))) next
      rec <- jsonlite::fromJSON(line, simplifyVector = FALSE)
      reg$papers[[rec$pmid]] <- rec
    }
  }
  reg
}
