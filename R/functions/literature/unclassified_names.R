# The method names of the register's usable papers that the vocabulary
# doesn't know yet, most used first: name, papers (each paper once) and up
# to three of the variant wordings they came with (for Claude's context).
unclassified_names <- function(reg, vocab) {
  rows <- list()
  for (p in Filter(function(p) isTRUE(p$usable), reg$papers)) {
    for (m in p$methods %||% list()) {
      if (!is.null(vocab$names[[m$name]])) next
      rows[[length(rows) + 1]] <- data.frame(pmid = p$pmid, name = m$name, variant = m$variant %||% "")
    }
  }
  if (length(rows) == 0) return(data.frame(name = character(0), papers = integer(0), variants = character(0)))
  all <- do.call(rbind, rows)
  out <- do.call(rbind, lapply(split(all, all$name), function(d) {
    v <- table(d$variant[nzchar(d$variant)])
    v <- names(sort(v, decreasing = TRUE))
    data.frame(name = d$name[1], papers = length(unique(d$pmid)), variants = paste(utils::head(v, 3), collapse = "; "))
  }))
  out <- out[order(-out$papers, out$name), , drop = FALSE]
  rownames(out) <- NULL
  out
}
