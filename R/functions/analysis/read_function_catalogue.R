# Reads the DataSHIELD function catalogue and keeps what an analyst can
# call: client functions ("ds." names, not server functions), with title
# and description. Since 2026-11-18 the catalogue (FederatedMethods/packages)
# publishes one packages.json (packages.datashield.org) with each package's
# roxygen blocks (catalogue_functions_from_packages()); the older
# datashield_functions_metadata.json (a table of functions with
# `architecture_type`) is still read if `url` points to one.
# Placeholder texts ("XXXX") become empty. Returns a data frame (package,
# function_name, title, description), empty — with a message — if the
# catalogue can't be read: notes then rest on package descriptions only.
read_function_catalogue <- function(url) {
  empty <- data.frame(package = character(0), function_name = character(0), title = character(0), description = character(0))
  raw <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE), error = function(e) {
    message(sprintf("Function catalogue %s could not be read: %s", url, conditionMessage(e)))
    NULL
  })
  if (is.null(raw)) {
    return(empty)
  }

  is_packages <- length(raw) > 0 && !is.null(names(raw)) &&
    all(vapply(raw, function(p) is.list(p) && !is.null(p$input), logical(1)))
  if (is_packages) {
    fns <- catalogue_functions_from_packages(raw)
  } else {
    table <- tryCatch(jsonlite::fromJSON(url), error = function(e) NULL)
    if (!is.data.frame(table) || !all(c("package", "function_name", "architecture_type") %in% names(table))) {
      message(sprintf("Function catalogue %s has neither the packages.json nor the older table format.", url))
      return(empty)
    }
    fns <- table[table$architecture_type %in% "client", intersect(c("package", "function_name", "title", "description"), names(table))]
  }
  for (col in c("title", "description")) {
    if (is.null(fns[[col]])) {
      fns[[col]] <- ""
    }
    fns[[col]][is.na(fns[[col]]) | grepl("^X{3,}$", trimws(fns[[col]]))] <- ""
  }
  rownames(fns) <- NULL
  fns
}
