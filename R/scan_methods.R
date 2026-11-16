#!/usr/bin/env Rscript
# The researcher of the hub for missing DataSHIELD functions, run by
# methods-scan.yml (dev-notes/issue-agents.md, "A central hub"). Modes
# (SCAN_MODE), built one at a time:
#   pilot  phase 0: open-access papers of one query (SCAN_QUERY, else the
#          first), methods named in the abstract against the methods
#          section, as a report (methods_pilot_report.md, plus
#          methods_pilot.json with every method found). Nothing committed.
# Papers come from PubMed and PMC (NCBI E-utilities); Claude only reads
# them (profile methods-extraction), through the subscription or WIF.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/methods")) "R/functions" else ".shared-workflows/R/functions"
walk(list.files(file.path(functions_dir, c("shared", "methods")), pattern = "\\.R$", full.names = TRUE), source)

settings <- read_config_yaml("config/methods-scan.yml")
mode <- Sys.getenv("SCAN_MODE", "pilot")
if (!identical(mode, "pilot")) {
  stop(sprintf("Mode %s isn't built yet; only pilot is.", mode), call. = FALSE)
}
queries <- settings$queries %||% list()
if (length(queries) == 0) {
  stop("No queries in config/methods-scan.yml.", call. = FALSE)
}
wanted <- Sys.getenv("SCAN_QUERY")
query <- if (nzchar(wanted)) Find(function(q) identical(q$name, wanted), queries) else queries[[1]]
if (is.null(query)) {
  stop(sprintf("No query named %s in config/methods-scan.yml.", wanted), call. = FALSE)
}

maxdate <- Sys.Date()
mindate <- seq(maxdate, by = sprintf("-%d months", settings$pilot$months %||% 12), length.out = 2)[2]
period <- sprintf("%s to %s", mindate, maxdate)
term <- sprintf('(%s) AND "pubmed pmc open access"[filter]', query$pubmed)
pmids <- search_pubmed(term, format(mindate, "%Y/%m/%d"), format(maxdate, "%Y/%m/%d"), settings$pilot$papers %||% 100, settings)
message(sprintf("%d open-access papers found for %s (%s).", length(pmids), query$name, period))

papers <- fetch_pubmed_abstracts(pmids, settings)
papers <- papers[nzchar(papers$pmcid) & nzchar(papers$abstract), ]
sections <- fetch_methods_sections(papers$pmcid, settings)
papers$methods <- unname(sections[papers$pmcid])
papers <- papers[!is.na(papers$methods) & nzchar(papers$methods), ]
message(sprintf("%d papers with an abstract and a methods section.", nrow(papers)))
if (nrow(papers) == 0) {
  stop("No paper to compare: try a broader query.", call. = FALSE)
}

claude <- claude_client("methods-extraction", "prompts/methods-extraction-prompt.md")
found <- ask_claude_for_method_sources(claude, papers, settings)
compared <- attr(found, "asked")
if (compared == 0) {
  stop("No paper could be compared (see the messages above): no report.", call. = FALSE)
}
summary <- summarise_method_sources(found, compared, settings$pilot$top %||% 20)
report <- format_pilot_report(summary, query$name, period)
if (isTRUE(attr(found, "stopped"))) {
  # Not lost: the report covers the papers compared so far; a new run after
  # the limit's reset starts again.
  report <- c(report, "", sprintf("_Stopped at the subscription's usage limit after %d of %d papers; the numbers cover those._",
    compared, nrow(papers)))
}
writeLines(report, "methods_pilot_report.md")
write_json(list(query = query, period = period, papers = papers[, c("pmid", "pmcid", "title")], methods = found),
  "methods_pilot.json", auto_unbox = TRUE, pretty = TRUE)
cat(report, sep = "\n")
