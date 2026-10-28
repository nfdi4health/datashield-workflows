# A name as comparable lowercase words, in their original order: accents
# transliterated (é -> e), punctuation dropped. Used by find_author().
name_tokens <- function(x) {
  x <- paste(x, collapse = " ")
  ascii <- iconv(x, to = "ASCII//TRANSLIT")
  if (!is.na(ascii)) {
    x <- ascii
  }
  x <- tolower(gsub("[^A-Za-z]+", " ", x))
  words <- strsplit(trimws(x), " ")[[1]]
  words[nzchar(words)]
}
