# The stored "Exists in DataSHIELD?" verdict of a method (variant "") or of
# one of its variants, or NULL.
exists_record <- function(vocab, method, variant = "") {
  m <- vocab$methods[[method]]
  if (nzchar(variant)) m$variants[[variant]]$exists else m$exists
}
