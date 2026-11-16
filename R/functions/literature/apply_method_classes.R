# Writes Claude's name classification into the vocabulary: each name of
# `asked` that the answer covers maps to its method key and implied
# variant (method "" when it isn't a method); new keys become methods.
# Names the answer left out stay unclassified (asked again next run).
apply_method_classes <- function(vocab, answer, asked, today, by) {
  for (a in answer$names %||% list()) {
    if (!a$name %in% asked) next
    if (isTRUE(a$not_a_method)) {
      vocab$names[[a$name]] <- list(method = "", by = by)
      next
    }
    key <- vocabulary_key(a$method_key)
    if (!nzchar(key)) next
    vocab <- add_vocabulary_method(vocab, key, a$method_name, a$description, a$keywords, today, by)
    entry <- list(method = key)
    variant <- normalise_method_name(a$implied_variant %||% "")
    if (nzchar(variant)) entry$variant <- variant
    entry$by <- by
    vocab$names[[a$name]] <- entry
  }
  vocab
}
