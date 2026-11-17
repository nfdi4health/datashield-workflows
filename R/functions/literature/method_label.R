# How a method (and a variant) key reads in the report: the vocabulary's
# name, else the key itself (a name not classified yet).
method_label <- function(vocab, method, variant = "") {
  m <- vocab$methods[[method]]
  label <- m$name %||% method
  if (nzchar(variant)) label <- m$variants[[variant]]$name %||% variant
  label
}
