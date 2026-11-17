# The variants of a set of usable papers: method, variant and in how many
# papers, those named in at least `min_papers`, most frequent first. In
# the vocabulary's terms (paper_methods()), keys, not labels.
variant_table <- function(papers, min_papers = 2, top = 20, vocab = list()) {
  rows <- unlist(lapply(Filter(function(p) isTRUE(p$usable), papers), function(p) {
    m <- paper_methods(p, vocab)
    m <- m[m$variant != "", , drop = FALSE]
    unique(paste(m$method, m$variant, sep = "\r"))
  }))
  if (length(rows) == 0) return(NULL)
  counts <- table(rows)
  counts <- counts[counts >= min_papers]
  if (length(counts) == 0) return(NULL)
  parts <- strsplit(names(counts), "\r", fixed = TRUE)
  out <- data.frame(method = vapply(parts, `[`, "", 1), variant = vapply(parts, `[`, "", 2), papers = as.integer(counts))
  utils::head(out[order(-out$papers, out$method, out$variant), , drop = FALSE], top)
}
