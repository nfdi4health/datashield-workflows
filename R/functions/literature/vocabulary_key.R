# A vocabulary key from Claude's answer: lower case, ASCII letters and
# digits, words joined by single hyphens ("Fisher's exact test" ->
# "fishers-exact-test"); "" when nothing is left.
vocabulary_key <- function(x) {
  x <- tolower(iconv(x %||% "", to = "ASCII//TRANSLIT", sub = ""))
  x <- gsub("'", "", x, fixed = TRUE)
  x <- gsub("[^a-z0-9]+", "-", x)
  gsub("^-+|-+$", "", x)
}
