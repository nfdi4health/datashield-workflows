# Adds a method to the vocabulary unless its key exists already (the
# first description wins; a later answer can't rename a method).
add_vocabulary_method <- function(vocab, key, name, description, keywords, today, by) {
  if (!nzchar(key) || !is.null(vocab$methods[[key]])) return(vocab)
  vocab$methods[[key]] <- list(name = if (nzchar(name %||% "")) name else key,
    description = description %||% "", keywords = as.list(normalise_method_name(unlist(keywords))),
    added = as.character(today), by = by)
  vocab
}
