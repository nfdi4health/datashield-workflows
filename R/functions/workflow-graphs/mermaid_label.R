# A diagram box label from lines of text: each line escaped
# (mermaid_text()) and wrapped at `width` characters, all joined with
# <br/>. The wrapping is done here because GitHub's Mermaid gives boxes a
# fixed width and cuts off what doesn't fit instead of growing the box.
# Long words without spaces (repository paths, file names) are broken
# after "/", and only where that isn't enough after "-", so
# "nfdi4health/datashield-workflows" becomes "nfdi4health/" +
# "datashield-workflows". NULL / NA / "" lines are skipped.
mermaid_label <- function(lines, width = 26) {
  lines <- unlist(lines)
  lines <- lines[!is.na(lines) & nzchar(lines)]
  wrap_line <- function(line) {
    # Pieces: words, and long words split after / or -; `glue` says whether
    # a piece continues the previous one without a space.
    pieces <- character(0)
    glue <- logical(0)
    for (word in strsplit(line, " ", fixed = TRUE)[[1]]) {
      split_after <- function(x, char) {
        if (nchar(x) <= width) {
          return(x)
        }
        p <- regmatches(x, gregexpr(sprintf("[^%s]*%s?", char, char), x))[[1]]
        p[nzchar(p)]
      }
      parts <- unlist(lapply(split_after(word, "/"), split_after, char = "-"))
      pieces <- c(pieces, parts)
      glue <- c(glue, FALSE, rep(TRUE, length(parts) - 1))
    }
    out <- character(0)
    current <- ""
    for (i in seq_along(pieces)) {
      # A piece of a split word is glued on without a space.
      if (!nzchar(current)) {
        candidate <- pieces[i]
      } else if (glue[i]) {
        candidate <- paste0(current, pieces[i])
      } else {
        candidate <- paste0(current, " ", pieces[i])
      }
      if (nchar(candidate) > width && nzchar(current)) {
        out <- c(out, current)
        current <- pieces[i]
      } else {
        current <- candidate
      }
    }
    c(out, current)
  }
  paste(mermaid_text(unlist(lapply(lines, wrap_line))), collapse = "<br/>")
}
