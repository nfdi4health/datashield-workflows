# One method entry of a paper (its name and variant wording, as the reader
# gave them) in the vocabulary's terms: list(method = key, variants = keys,
# known = whether the name is classified). A name that isn't a method gives
# method NA. A name not classified yet keeps its own wording as key, so the
# report works before and while the vocabulary grows; so does a variant
# wording not classified yet. A variant classified as a method of its own
# replaces the method (its other variants then go with it).
resolve_method <- function(vocab, name, variant = "") {
  entry <- vocab$names[[name]]
  if (is.null(entry)) {
    return(list(method = name, variants = split_variants(variant), known = FALSE))
  }
  method <- entry$method %||% ""
  if (!nzchar(method)) return(list(method = NA_character_, variants = character(0), known = TRUE))
  wordings <- unique(c(split_variants(entry$variant %||% ""), split_variants(variant)))
  variants <- character(0)
  for (w in wordings) {
    v <- vocab$variant_names[[method]][[w]]
    if (is.null(v)) {
      variants <- c(variants, w)
    } else if (nzchar(v$method %||% "")) {
      method <- v$method
    } else if (nzchar(v$variant %||% "")) {
      variants <- c(variants, v$variant)
    }
  }
  list(method = method, variants = unique(variants), known = TRUE)
}
