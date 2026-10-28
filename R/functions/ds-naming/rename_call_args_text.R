# Text fallback for what R can't parse (Rd \usage and \examples, roxygen
# @examples, vignette chunks): renames the argument `old` of calls to
# `fn` to `new` — `old =` directly inside `fn( ... )`, not in nested
# calls or strings. With `formals = TRUE` (an Rd \usage) also a bare
# `old` followed by `,` or `)`. Returns list(lines, done).
rename_call_args_text <- function(lines, fn, old, new, formals = FALSE) {
  text <- paste(lines, collapse = "\n")
  id_char <- "[A-Za-z0-9._]"
  starts <- gregexpr(paste0("(?<![A-Za-z0-9._])", gsub("([.])", "\\\\\\1", fn), "\\s*\\("), text, perl = TRUE)[[1]]
  if (starts[1] < 0) {
    return(list(lines = lines, done = 0))
  }
  chars <- strsplit(text, "")[[1]]
  n <- length(chars)
  hits <- integer(0)
  for (s in starts + attr(starts, "match.length") - 1) {  # position of "("
    depth <- 0
    quote <- ""
    i <- s
    while (i <= n) {
      ch <- chars[i]
      if (nzchar(quote)) {
        if (ch == "\\") {
          i <- i + 1
        } else if (ch == quote) {
          quote <- ""
        }
      } else if (ch %in% c("\"", "'", "`")) {
        quote <- ch
      } else if (ch %in% c("(", "[", "{")) {
        depth <- depth + 1
      } else if (ch %in% c(")", "]", "}")) {
        depth <- depth - 1
        if (depth == 0) {
          break
        }
      } else if (depth == 1 && (i == 1 || !grepl(id_char, chars[i - 1])) && substr(text, i, i + nchar(old) - 1) == old) {
        rest <- substr(text, i + nchar(old), min(n, i + nchar(old) + 200))
        follows <- if (formals) {
          "^\\s*(=(?!=)|,|\\))"
        } else {
          "^\\s*=(?!=)"
        }
        if (!grepl(paste0("^", id_char), rest) && grepl(follows, rest, perl = TRUE)) {
          hits <- c(hits, i)
        }
      }
      i <- i + 1
    }
  }
  if (length(hits) == 0) {
    return(list(lines = lines, done = 0))
  }
  for (h in sort(unique(hits), decreasing = TRUE)) {
    text <- paste0(substr(text, 1, h - 1), new, substr(text, h + nchar(old), nchar(text)))
  }
  out <- strsplit(text, "\n", fixed = TRUE)[[1]]
  out <- c(out, rep("", length(lines) - length(out)))  # strsplit() drops trailing empty lines
  list(lines = out, done = length(unique(hits)))
}
