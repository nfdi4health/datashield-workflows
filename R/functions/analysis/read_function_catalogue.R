# Reads the DataSHIELD function catalogue (datashield_functions_metadata.json,
# extracted from the known packages' R files) and keeps what an analyst
# can call: exported client functions, with title and description.
# Placeholder texts ("XXXX") become empty. Returns a data frame (package,
# function_name, title, description), empty — with a message — if the
# catalogue can't be read: notes then rest on package descriptions only.
read_function_catalogue <- function(url) {
  empty <- data.frame(package = character(0), function_name = character(0), title = character(0), description = character(0))
  raw <- tryCatch(jsonlite::fromJSON(url), error = function(e) {
    message(sprintf("Function catalogue %s could not be read: %s", url, conditionMessage(e)))
    NULL
  })
  if (!is.data.frame(raw) || !all(c("package", "function_name", "architecture_type") %in% names(raw))) {
    return(empty)
  }

  fns <- raw[raw$architecture_type %in% "client", intersect(c("package", "function_name", "title", "description"), names(raw))]
  for (col in c("title", "description")) {
    if (is.null(fns[[col]])) {
      fns[[col]] <- ""
    }
    fns[[col]][is.na(fns[[col]]) | grepl("^X{3,}$", trimws(fns[[col]]))] <- ""
  }
  rownames(fns) <- NULL
  fns
}
