# The methods of a set of papers (usable ones only), each paper counted
# once per method: the share of papers using it over the `recent` months
# (the ranking), and per year of `years` its share, with the papers read
# that year and the trend (method_trend()). The `top` methods by recent
# share. Methods in the vocabulary's terms (paper_methods(): names merged
# into methods, names that aren't methods left out); with an empty
# vocabulary the reader's own names.
method_table <- function(papers, years, recent, top = 20, vocab = list()) {
  papers <- Filter(function(p) isTRUE(p$usable), papers)
  if (length(papers) == 0) return(NULL)
  year <- substr(vapply(papers, function(p) p$month, ""), 1, 4)
  in_recent <- vapply(papers, function(p) p$month %in% recent, logical(1))
  used <- lapply(papers, function(p) {
    m <- paper_methods(p, vocab)
    unique(m$method[m$variant == ""])
  })
  all <- sort(unique(unlist(used)))
  if (length(all) == 0) return(NULL)
  n_year <- vapply(years, function(y) sum(year == y), numeric(1))
  rows <- lapply(all, function(m) {
    has <- vapply(used, function(u) m %in% u, logical(1))
    k_year <- vapply(years, function(y) sum(has & year == y), numeric(1))
    data.frame(method = m, papers = sum(has & in_recent),
      share = if (sum(in_recent) > 0) sum(has & in_recent) / sum(in_recent) else NA_real_,
      trend = method_trend(as.numeric(years), k_year, n_year),
      t(stats::setNames(ifelse(n_year > 0, k_year / n_year, NA_real_), years)), check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  out <- out[order(-out$share, out$method), , drop = FALSE]
  attr(out, "papers_recent") <- sum(in_recent)
  attr(out, "papers_year") <- stats::setNames(n_year, years)
  utils::head(out, top)
}
