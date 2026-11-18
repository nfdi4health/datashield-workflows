# Every method and variant of the vocabulary (method_units(); whether
# DataSHIELD has it is checked later, down this ranking:
# exists_for_ranked()) with its use in the usable papers of all the months
# read (`months`, all fields, each paper once): `papers` and `share` over
# all years, `recent_papers` and `recent_share` over the last years
# (`recent`), the trend by year (method_trend(): rising / falling /
# steady, p < 0.05), the fields using it most, and example papers (the
# newest). Keys in fewer than `candidates$min_papers` papers over all
# years are left out. `status`: "tracked" (a hub issue carries its marker:
# `tracked`, key -> issue number), "skipped" (don't suggest again, until
# its papers reach `resuggest_factor` times the count then), "deferred"
# (not now) or "new". Ordered by share over all years, rising trends first
# on ties: the "most used" list. The "on the rise" list is taken from the
# same table (candidates_literature.R).
rank_candidates <- function(reg, vocab, settings, decisions, tracked, months, recent) {
  cs <- settings$candidates
  units <- method_units(vocab)
  empty <- data.frame(key = character(0), method = character(0), variant = character(0), papers = integer(0),
    share = numeric(0), recent_papers = integer(0), recent_share = numeric(0), trend = character(0), status = character(0))
  if (nrow(units) == 0) return(empty)
  papers <- Filter(function(p) isTRUE(p$usable) && p$month %in% months, reg$papers)
  keys <- lapply(papers, function(p) {
    m <- paper_methods(p, vocab)
    unique(c(m$method[m$variant == ""], paste(m$method, m$variant, sep = "/")[m$variant != ""]))
  })
  in_recent <- vapply(papers, function(p) p$month %in% recent, logical(1))
  year <- substr(vapply(papers, function(p) p$month, ""), 1, 4)
  years <- sort(unique(substr(months, 1, 4)))
  n_year <- vapply(years, function(y) sum(year == y), numeric(1))
  rows <- lapply(seq_len(nrow(units)), function(i) {
    key <- units$key[i]
    has <- vapply(keys, function(k) key %in% k, logical(1))
    k_all <- sum(has)
    k_recent <- sum(has & in_recent)
    k_year <- vapply(years, function(y) sum(has & year == y), numeric(1))
    found <- unlist(lapply(papers[has], function(p) names(p$found_by)))
    fields <- names(utils::head(sort(table(found), decreasing = TRUE), 3))
    newest <- papers[has][order(vapply(papers[has], function(p) p$month, ""), decreasing = TRUE)]
    ex <- utils::head(newest, cs$examples %||% 3)
    data.frame(papers = k_all, share = if (length(papers) > 0) k_all / length(papers) else 0,
      recent_papers = k_recent, recent_share = if (sum(in_recent) > 0) k_recent / sum(in_recent) else 0,
      trend = method_trend(as.numeric(years), k_year, n_year), total = k_all,
      fields = paste(fields, collapse = ", "),
      examples = jsonlite::toJSON(lapply(ex, function(p) list(pmid = p$pmid, title = p$title %||% "", journal = p$journal %||% "")), auto_unbox = TRUE))
  })
  out <- cbind(units, do.call(rbind, rows))
  out <- out[out$papers >= (cs$min_papers %||% 5), , drop = FALSE]
  out$status <- vapply(seq_len(nrow(out)), function(i) {
    key <- out$key[i]
    d <- decisions[[key]]
    if (!is.null(tracked[[key]])) return("tracked")
    if (identical(d$decision, "issue")) return("tracked")
    if (identical(d$decision, "dont-suggest")) {
      return(if (out$papers[i] >= (cs$resuggest_factor %||% 2) * (d$papers %||% 0)) "new" else "skipped")
    }
    if (identical(d$decision, "not-now")) return("deferred")
    "new"
  }, "")
  rising <- out$trend == "rising"
  out[order(-out$share, !rising, out$key), , drop = FALSE]
}
