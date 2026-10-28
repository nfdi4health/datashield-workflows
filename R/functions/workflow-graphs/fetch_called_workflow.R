# Reads a called reusable workflow (a parse_workflow_ref() result) and
# parses it: from the repository itself for a local reference, otherwise
# through the GitHub API at the referenced ref. Returns NULL if the file
# can't be read — e.g. a private repository the token can't see — so the
# diagram can still show the call, marked as not readable.
fetch_called_workflow <- function(ref) {
  text <- if (isTRUE(ref$local)) {
    if (file.exists(ref$path)) {
      paste(readLines(ref$path, warn = FALSE), collapse = "\n")
    } else {
      NULL
    }
  } else {
    body <- get_github_json(sprintf("/repos/%s/%s/contents/%s?ref=%s",
                                    ref$owner, ref$repo, ref$path, utils::URLencode(ref$ref, reserved = TRUE)))
    if (is.null(body$content)) {
      NULL
    } else {
      rawToChar(jsonlite::base64_dec(gsub("\n", "", body$content)))
    }
  }
  if (is.null(text)) {
    return(NULL)
  }
  tryCatch(parse_workflow_yaml(text, ref$file), error = function(e) NULL)
}
