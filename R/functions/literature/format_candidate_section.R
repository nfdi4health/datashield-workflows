# One candidate's section of the candidate pull request: its boxes
# (candidate_boxes()), how often and where it is used, the DataSHIELD
# verdict, Claude's brief (`research`, research_candidate()) and example
# papers.
format_candidate_section <- function(i, row, vocab, research) {
  name <- method_label(vocab, row$method)
  title <- if (nzchar(row$variant)) sprintf("%s: %s", name, method_label(vocab, row$method, row$variant)) else name
  verdict <- switch(row$verdict, none = "no", partial = sprintf("partly (`%s`)", row[["function"]]), row$verdict)
  examples <- jsonlite::fromJSON(row$examples, simplifyVector = FALSE)
  out <- c(sprintf("### %d. %s", i, title), "", candidate_boxes(row$key), "",
    sprintf("Used in %.1f%% of the sampled papers of all years read (%d papers), %.1f%% in the last years (%d), trend: %s. Mostly in: %s.",
      100 * row$share, row$papers, 100 * (row$recent_share %||% row$share), row$recent_papers %||% row$papers, row$trend, row$fields),
    sprintf("In DataSHIELD: %s.%s", verdict, if (nzchar(row$note)) paste0(" ", candidate_text(row$note)) else ""), "")
  if (is.null(research)) {
    out <- c(out, "_The research step couldn't run for this one; it is tried again with the next pull request._", "")
  } else {
    pk <- vapply(research$r_packages, function(p) sprintf("`%s::%s` (%s)", p$package, p[["function"]], p$note), "")
    out <- c(out, sprintf("**What it is:** %s", research$description), "",
      sprintf("**In R:** %s", if (length(pk) == 0) "no package found." else paste(pk, collapse = "; ")), "",
      sprintf("**Federated:** %s", research$federated), "",
      sprintf("**Disclosure, a first view:** %s", research$disclosure), "",
      sprintf("**Would fit:** %s", research$fit), "")
    if (length(research$sources) > 0) out <- c(out, sprintf("Sources: %s", paste(sprintf("<%s>", unlist(research$sources)), collapse = ", ")), "")
  }
  if (length(examples) > 0) {
    out <- c(out, sprintf("Example papers: %s", paste(vapply(examples, function(e)
      sprintf("[%s](https://pubmed.ncbi.nlm.nih.gov/%s/)", candidate_text(e$title), e$pmid), ""), collapse = "; ")), "")
  }
  out
}
