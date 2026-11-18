# What the literature watch knows about a hub issue's method (the idea
# check, R/check_ideas.R): its vocabulary key (match_vocabulary_method())
# and in how many of the usable papers read so far it is named
# (method_paper_counts()). NULL without a match or without data.
idea_literature <- function(method, vocab, reg) {
  if (is.null(vocab) || length(vocab$methods) == 0) return(NULL)
  key <- match_vocabulary_method(vocab, method)
  if (!nzchar(key)) return(NULL)
  parts <- strsplit(key, "/", fixed = TRUE)[[1]]
  counts <- method_paper_counts(reg, vocab)
  hit <- counts$papers[counts$method == parts[1] & counts$variant == (if (length(parts) > 1) parts[2] else "")]
  usable <- sum(vapply(reg$papers, function(p) isTRUE(p$usable), logical(1)))
  list(key = key, papers = if (length(hit)) hit[1] else 0L, usable = usable)
}
