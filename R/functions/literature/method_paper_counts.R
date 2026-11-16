# In how many usable papers of the register each method and each method's
# variant is used, in the vocabulary's terms (paper_methods()): a data
# frame of method, variant ("" for the method itself) and papers, only
# classified methods.
method_paper_counts <- function(reg, vocab) {
  rows <- lapply(Filter(function(p) isTRUE(p$usable), reg$papers), function(p) {
    m <- paper_methods(p, vocab)
    m <- m[m$method %in% names(vocab$methods), , drop = FALSE]
    if (nrow(m) == 0) return(NULL)
    cbind(pmid = p$pmid, m)
  })
  all <- do.call(rbind, c(list(data.frame(pmid = character(0), method = character(0), variant = character(0))), rows))
  if (nrow(all) == 0) return(data.frame(method = character(0), variant = character(0), papers = integer(0)))
  out <- stats::aggregate(pmid ~ method + variant, data = unique(all), FUN = length)
  names(out)[names(out) == "pmid"] <- "papers"
  out[order(-out$papers, out$method, out$variant), , drop = FALSE]
}
