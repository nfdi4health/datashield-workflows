# The variant wordings the vocabulary doesn't know yet, per method: of the
# register's usable papers whose method name is classified, the wordings
# of their variants and of the variants their names imply. A data frame of
# method, variant (the wording) and papers, most used first.
unclassified_variants <- function(reg, vocab) {
  rows <- list()
  for (p in Filter(function(p) isTRUE(p$usable), reg$papers)) {
    for (m in p$methods %||% list()) {
      entry <- vocab$names[[m$name]]
      if (is.null(entry) || !nzchar(entry$method %||% "")) next
      for (w in unique(c(split_variants(entry$variant %||% ""), split_variants(m$variant %||% "")))) {
        if (!is.null(vocab$variant_names[[entry$method]][[w]])) next
        rows[[length(rows) + 1]] <- data.frame(pmid = p$pmid, method = entry$method, variant = w)
      }
    }
  }
  if (length(rows) == 0) return(data.frame(method = character(0), variant = character(0), papers = integer(0)))
  all <- unique(do.call(rbind, rows))
  out <- stats::aggregate(pmid ~ method + variant, data = all, FUN = length)
  names(out)[names(out) == "pmid"] <- "papers"
  out <- out[order(out$method, -out$papers, out$variant), , drop = FALSE]
  rownames(out) <- NULL
  out
}
