# The research step for one candidate (a row of rank_candidates()): Claude
# with web search writes a short brief (build_research_tool()). Returns
# list(research = the brief with its texts cleaned (candidate_text()), or
# NULL, limit = TRUE at the usage limit).
research_candidate <- function(claude, row, vocab) {
  m <- vocab$methods[[row$method]]
  lines <- c(
    sprintf("Method: %s. %s", m$name %||% row$method, m$description %||% ""),
    if (nzchar(row$variant)) sprintf("Variant: %s (the plain method exists in some form; this is about the variant).",
      method_label(vocab, row$method, row$variant)),
    sprintf("DataSHIELD verdict: %s%s. %s", row$verdict, if (nzchar(row[["function"]])) sprintf(" (closest: %s)", row[["function"]]) else "",
      row$note),
    sprintf("Used in %.1f%% of the sampled health research papers of all years read (%d papers), %.1f%% in the last years, trend %s, mostly in: %s.",
      100 * row$share, row$papers, 100 * (row$recent_share %||% row$share), row$trend, row$fields))
  res <- call_watch_claude(claude, build_research_tool(), fill_template(claude$prompt, list(CANDIDATE = paste(lines, collapse = "\n"))),
    sprintf("research on %s", row$key))
  if (is.null(res$answer)) return(list(research = NULL, limit = res$limit))
  a <- res$answer
  list(limit = FALSE, research = list(
    description = candidate_text(a$description), federated = candidate_text(a$federated),
    disclosure = candidate_text(a$disclosure), fit = candidate_text(a$fit),
    r_packages = lapply(utils::head(a$r_packages %||% list(), 4), function(p) list(package = candidate_text(p$package),
      `function` = candidate_text(p[["function"]]), note = candidate_text(p$note))),
    sources = as.list(utils::head(grep("^https?://", vapply(a$sources %||% list(), candidate_text, ""), value = TRUE), 6))))
}
