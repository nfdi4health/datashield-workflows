# The roxygen block directly above line `def_line` of `lines`: the @param
# texts by argument name (`@param a,b text` documents both; continuation
# lines are joined) and the set of tags used. Blank lines and plain
# comments between the block and the definition are tolerated.
roxygen_params <- function(lines, def_line) {
  # all #' lines above, blank lines and plain comments in between allowed
  # (roxygen2 takes every #' line since the previous expression)
  i <- def_line - 1
  while (i >= 1 && (!nzchar(trimws(lines[i])) || grepl("^\\s*#", lines[i]))) {
    i <- i - 1
  }
  above <- if (def_line > 1) {
    (i + 1):(def_line - 1)
  } else {
    integer(0)
  }
  above <- above[above >= 1 & above <= def_line - 1]
  block <- sub("^\\s*#'\\s?", "", lines[above[grepl("^\\s*#'", lines[above])]])

  params <- list()
  tags <- character(0)
  current <- NULL
  for (ln in block) {
    if (grepl("^\\s*@\\w+", ln)) {
      tag <- sub("^\\s*@(\\w+).*$", "\\1", ln)
      tags <- union(tags, tag)
      current <- NULL
      if (tag == "param") {
        rest <- trimws(sub("^\\s*@param\\s*", "", ln))
        arg_names <- trimws(strsplit(sub("\\s.*$", "", rest), ",")[[1]])
        arg_names <- arg_names[nzchar(arg_names)]
        text <- trimws(sub("^\\S+\\s*", "", rest))
        for (nm in arg_names) {
          params[[nm]] <- text
        }
        current <- arg_names
      }
    } else if (!is.null(current)) {
      for (nm in current) {
        params[[nm]] <- trimws(paste(params[[nm]], trimws(ln)))
      }
    }
  }
  list(params = params, tags = tags)
}
