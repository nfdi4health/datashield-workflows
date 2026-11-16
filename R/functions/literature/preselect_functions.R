# The candidate functions for one method: those whose name, title or
# description share most of the method's words (its name, keywords and
# variant), at most `n`, best first. A phrase found counts once per field
# it occurs in, in the function's name twice. Words under three letters
# and common filler words don't count.
preselect_functions <- function(inventory, words, n = 15) {
  if (is.null(inventory) || nrow(inventory) == 0) return(inventory[0, , drop = FALSE])
  stop_words <- c("the", "and", "for", "with", "model", "models", "analysis", "test", "method", "data", "regression")
  terms <- unique(tolower(trimws(unlist(words))))
  single <- unique(unlist(strsplit(terms, "[^a-z0-9]+")))
  terms <- unique(c(terms[grepl(" ", terms)], single))
  terms <- terms[nchar(terms) >= 3 & !terms %in% stop_words]
  if (length(terms) == 0) return(inventory[0, , drop = FALSE])
  name <- tolower(inventory$fn)
  text <- tolower(paste(inventory$title, inventory$description))
  score <- vapply(seq_len(nrow(inventory)), function(i) {
    sum(vapply(terms, function(t) 2 * grepl(t, name[i], fixed = TRUE) + grepl(t, text[i], fixed = TRUE), numeric(1)))
  }, numeric(1))
  keep <- which(score > 0)
  keep <- keep[order(-score[keep], inventory$package[keep], inventory$fn[keep])]
  inventory[utils::head(keep, n), , drop = FALSE]
}
