# Short, stable fingerprints of texts, one per element (the first `n` hex
# characters of each one's MD5): of a field's search (which version of a
# query found a paper), of a model and prompt (which reader read it), and
# of field and PubMed ID (a paper's place in the field's random order).
hash_keys <- function(x, n = 8) {
  substr(as.character(openssl::md5(enc2utf8(as.character(x)))), 1, n)
}
