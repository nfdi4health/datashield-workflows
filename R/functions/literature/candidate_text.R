# Text from Claude or the papers for the hub's public pull request and
# issues: no @-mentions (a zero-width space after @), no HTML comments
# (which could fake the candidates' markers), single spaces.
candidate_text <- function(x) {
  x <- gsub("<!--|-->", "", x %||% "")
  x <- gsub("@", "@​", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}
