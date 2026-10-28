# Reads the analyst's real login file (01_DS_Login.R) mechanically — it is
# never sent to Claude — and returns list(connections, notes):
# - the name of the connections object (`conns` in the dsAnalysis
#   template), which the generated scripts pass as `datasources`;
# - a warning if a line matches `credential_pattern` (settings), e.g. a
#   password written as text instead of read with Sys.getenv(): the file
#   is in the repository;
# - notes if its server names or symbol differ from the plan, since the
#   scripts are written for the plan's.
# Only line numbers are reported, never the values. Wording from
# `texts$notes`.
check_login_file <- function(path, plan, credential_pattern, texts) {
  if (!file.exists(path)) {
    return(list(connections = "conns", notes = fill_template(texts$notes$no_login_file, list(PATH = path))))
  }
  notes <- character(0)
  code <- sub("#.*$", "", readLines(path, warn = FALSE))

  secret_lines <- grep(credential_pattern, code, ignore.case = TRUE)
  if (length(secret_lines) > 0) {
    notes <- c(notes, fill_template(texts$notes$credentials, list(PATH = path, LINES = paste(secret_lines, collapse = ", "))))
  }

  text <- paste(code, collapse = "\n")
  pick <- function(pattern) {
    m <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
    sub(pattern, "\\1", m, perl = TRUE)
  }
  connections <- pick("([A-Za-z.][A-Za-z0-9._]*)\\s*(?:<<-|<-|=)\\s*(?:DSI::)?datashield\\.login\\s*\\(")
  connections <- if (length(connections) > 0) {
    connections[1]
  } else {
    "conns"
  }

  quoted <- function(x) paste(sprintf("`%s`", x), collapse = ", ")
  servers <- pick("server\\s*=\\s*[\"']([^\"']+)[\"']")
  planned <- vapply(plan$studies, function(s) s$server, character(1))
  if (length(servers) > 0 && !setequal(servers, planned)) {
    notes <- c(notes, fill_template(texts$notes$servers_differ, list(PATH = path, FOUND = quoted(servers), PLANNED = quoted(planned))))
  }
  symbol <- pick("symbol\\s*=\\s*[\"']([^\"']+)[\"']")
  if (length(symbol) > 0 && !identical(symbol[1], plan$symbol)) {
    notes <- c(notes, fill_template(texts$notes$symbol_differs, list(PATH = path, FOUND = symbol[1], PLANNED = plan$symbol)))
  }

  list(connections = connections, notes = notes)
}
