# The DataSHIELD functions "Exists?" checks against: the catalogue's
# inventory (FederatedMethods/packages: datashield_functions_metadata.json,
# each function's package, architecture, title and description, extracted
# from the packages' roxygen) with each package's status from its
# package_list.csv. Retired packages, functions of other architectures
# (`exists$architectures`), server functions the inventory lists as
# "other" (names ending in DS, DS1, DS2 or DS.<suffix>, e.g. glmDS2,
# vcovDS.coxph) and placeholder documentation ("XXXX") are left out. A data frame of package, fn, title, description, status; NULL if
# either file can't be read (the step is then skipped for this run).
read_function_inventory <- function(settings) {
  e <- settings$exists
  fetch <- function(url) {
    tryCatch(httr2::resp_body_string(httr2::req_perform(httr2::req_retry(httr2::request(url), max_tries = 3))),
      error = function(err) {
        message(sprintf("Could not read %s: %s", url, conditionMessage(err)))
        NULL
      })
  }
  functions <- fetch(e$functions_url %||% "https://raw.githubusercontent.com/FederatedMethods/packages/main/datashield_functions_metadata.json")
  packages <- fetch(e$packages_url %||% "https://raw.githubusercontent.com/FederatedMethods/packages/main/package_list.csv")
  if (is.null(functions) || is.null(packages)) return(NULL)
  fns <- jsonlite::fromJSON(functions, simplifyVector = TRUE)
  pk <- utils::read.delim(text = packages, sep = "|", strip.white = TRUE, na.strings = "", stringsAsFactors = FALSE)
  status <- stats::setNames(tolower(trimws(pk$status %||% rep("", nrow(pk))))[seq_len(nrow(pk))], trimws(pk$name))
  status[is.na(status)] <- ""
  keep <- fns$architecture_type %in% unlist(e$architectures %||% list("client", "other")) &
    !grepl("DS[0-9]*($|\\.)", fns$function_name)
  fns <- fns[keep, , drop = FALSE]
  out <- data.frame(package = fns$package, fn = fns$function_name,
    title = ifelse(is.na(fns$title), "", fns$title), description = ifelse(is.na(fns$description), "", fns$description),
    stringsAsFactors = FALSE)
  out$status <- unname(ifelse(out$package %in% names(status), status[out$package], ""))
  placeholder <- function(x) !nzchar(trimws(x)) | grepl("^X+$", trimws(x))
  out <- out[out$status != "retired" & !(placeholder(out$title) & placeholder(out$description)), , drop = FALSE]
  rownames(out) <- NULL
  out
}
