# Writes Claude's variant classification for one method into the
# vocabulary: each wording of `asked` maps to a variant key (new ones
# become variants of the method), to a method of its own (new keys become
# methods), or to no variant. Wordings the answer left out stay
# unclassified.
apply_variant_classes <- function(vocab, method, answer, asked, today, by) {
  if (is.null(vocab$variant_names[[method]])) vocab$variant_names[[method]] <- list()
  for (a in answer$variants %||% list()) {
    if (!a$variant %in% asked) next
    if (isTRUE(a$not_a_variant)) {
      vocab$variant_names[[method]][[a$variant]] <- list(variant = "", by = by)
    } else if (isTRUE(a$own_method)) {
      key <- vocabulary_key(a$method_key)
      if (!nzchar(key)) next
      vocab <- add_vocabulary_method(vocab, key, a$method_name, a$description, a$keywords, today, by)
      vocab$variant_names[[method]][[a$variant]] <- list(method = key, by = by)
    } else {
      key <- vocabulary_key(a$variant_key)
      if (!nzchar(key)) next
      if (is.null(vocab$methods[[method]]$variants[[key]])) {
        vocab$methods[[method]]$variants[[key]] <- list(name = if (nzchar(a$variant_name %||% "")) a$variant_name else key)
      }
      vocab$variant_names[[method]][[a$variant]] <- list(variant = key, by = by)
    }
  }
  vocab
}
