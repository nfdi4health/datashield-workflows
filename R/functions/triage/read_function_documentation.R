# The roxygen documentation of the function in one file of R/ on the
# default branch, for the triage to compare a report with what the function
# is documented to do: the call with its arguments and the block's text
# (without examples, imports and export), cut to
# settings$max_documentation_chars. Only the documentation, never
# the code: triage decides whether behaviour is meant, not why it happens
# (that is the implementer's work). `documented` is FALSE for a file whose
# function has no roxygen block; NULL if the file can't be read or holds
# no function.
read_function_documentation <- function(file, settings) {
  path <- sprintf("R/%s", file)
  content <- get_github_json(sprintf("/repos/%s/contents/%s", repo, utils::URLencode(path)))
  if (is.null(content$content)) {
    return(NULL)
  }
  local <- tempfile(fileext = ".R")
  on.exit(unlink(local), add = TRUE)
  writeBin(jsonlite::base64_dec(gsub("\\s", "", content$content)), local)
  parsed <- tryCatch(suppressWarnings(parse_r_file(local)), error = function(e) NULL)
  if (is.null(parsed)) {
    return(NULL)
  }
  usage <- sprintf("%s(%s)", parsed$fn_name, paste(parsed$params, collapse = ", "))
  # Tags that say nothing about behaviour are left out: examples (often the
  # longest part, a login and a call), imports and the export.
  lines <- sub("^\\s*#'\\s?", "", parsed$roxygen_lines)
  skip <- c("@examples", "@examplesIf", "@import", "@importFrom", "@export", "@rawNamespace", "@useDynLib")
  dropping <- FALSE
  kept <- character(0)
  for (line in lines) {
    tag <- regmatches(line, regexpr("^@[A-Za-z]+", line))
    if (length(tag) == 1) {
      dropping <- tag %in% skip
    }
    if (!dropping) {
      kept <- c(kept, line)
    }
  }
  text <- paste(kept, collapse = "\n")
  if (nchar(text) > settings$max_documentation_chars) {
    text <- paste0(substr(text, 1, settings$max_documentation_chars), "\n[... rest cut]")
  }
  list(file = path, name = parsed$fn_name, usage = usage, documented = isTRUE(parsed$has_roxygen), text = text)
}
