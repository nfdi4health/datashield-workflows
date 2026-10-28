# The character index in `line` of the parser's column `col`
# (getParseData()), which counts a tab as up to the next multiple of 8.
col_to_index <- function(line, col) {
  chars <- strsplit(line, "")[[1]]
  pos <- 0
  for (i in seq_along(chars)) {
    pos <- if (chars[i] == "\t") {
      (pos %/% 8 + 1) * 8
    } else {
      pos + 1
    }
    if (pos >= col) {
      return(i)
    }
  }
  NA_integer_
}
