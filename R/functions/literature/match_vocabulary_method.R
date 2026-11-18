# The literature watch's key for a method read from a hub issue, only on an
# exact match (user, 2026-11-18: a wrong match would merge two ideas): the
# name as a name the papers gave (normalise_method_name(), through
# resolve_method(); one implied variant gives "method/variant"), else the
# name's vocabulary_key() as a method key, else a method's own name. ""
# when nothing matches.
match_vocabulary_method <- function(vocab, name) {
  n <- normalise_method_name(name %||% "")
  if (!nzchar(n)) return("")
  if (!is.null(vocab$names[[n]])) {
    r <- resolve_method(vocab, n)
    if (!is.na(r$method) && r$method %in% names(vocab$methods)) {
      return(if (length(r$variants) == 1) paste(r$method, r$variants, sep = "/") else r$method)
    }
    return("")
  }
  key <- vocabulary_key(name)
  if (nzchar(key) && key %in% names(vocab$methods)) return(key)
  own <- vapply(vocab$methods, function(m) normalise_method_name(m$name %||% ""), "")
  hit <- names(own)[own == n]
  if (length(hit) == 1) hit else ""
}
