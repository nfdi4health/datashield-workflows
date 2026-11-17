# The methods of one paper in the vocabulary's terms (resolve_method()):
# a data frame of method and variant ("" for the method itself), each pair
# once, names that aren't methods left out. With an empty vocabulary the
# reader's own wordings.
paper_methods <- function(p, vocab) {
  rows <- lapply(p$methods %||% list(), function(m) {
    r <- resolve_method(vocab, m$name, m$variant %||% "")
    if (is.na(r$method)) return(NULL)
    data.frame(method = r$method, variant = c("", r$variants))
  })
  out <- do.call(rbind, c(list(data.frame(method = character(0), variant = character(0))), rows))
  unique(out)
}
