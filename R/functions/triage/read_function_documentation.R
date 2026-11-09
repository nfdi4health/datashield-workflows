# The roxygen documentation of the function in one file of R/ on the
# default branch, for the triage to compare a report with what the function
# is documented to do: the call with its arguments and the whole block's
# text, cut to settings$max_documentation_chars. Only the documentation, never
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
  # The whole block: examples too ("I followed your example" reports, and
  # wrong examples are documentation bugs), imports and the export (an
  # undeclared dependency, a function users can't reach).
  text <- paste(sub("^\\s*#'\\s?", "", parsed$roxygen_lines), collapse = "\n")
  if (nchar(text) > settings$max_documentation_chars) {
    text <- paste0(substr(text, 1, settings$max_documentation_chars), "\n[... rest cut]")
  }
  list(file = path, name = parsed$fn_name, usage = usage, documented = isTRUE(parsed$has_roxygen), text = text)
}
