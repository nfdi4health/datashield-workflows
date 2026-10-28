# The DataSHIELD packages the studies don't have yet, as prompt text: one
# line per server-side package whose catalogue status is in `statuses`
# (the plan's or the settings' package-status), not installed, with its
# status and description, followed by its client package's functions from
# the function catalogue (`functions`, read_function_catalogue()) with
# their titles. Notes name the server package (the one the study servers
# need); its client is the name + `client_suffix`. Packages only in the
# function catalogue count as status "unknown".
# Returns list(text, names, functions): `names` and `functions` are the
# enums for other_package notes.
format_catalogue_for_prompt <- function(catalogue, functions, installed, client_suffix, statuses) {
  status_of <- function(n) {
    catalogue[[n]]$status %||% "unknown"
  }
  from_functions <- sub(paste0(client_suffix, "$"), "", unique(functions$package[endsWith(functions$package, client_suffix)]))
  keep <- unique(c(names(catalogue), from_functions))
  keep <- setdiff(keep[!endsWith(keep, client_suffix)], installed)
  keep <- keep[vapply(keep, status_of, character(1)) %in% statuses]
  if (length(keep) == 0) {
    return(list(text = "(none)", names = character(0), functions = character(0)))
  }

  offered <- functions[functions$package %in% paste0(keep, client_suffix), ]
  lines <- unlist(lapply(sort(keep), function(n) {
    description <- catalogue[[n]]$description %||% ""
    own <- offered[offered$package == paste0(n, client_suffix), ]
    entry <- sprintf("- %s [%s]: %s", n, status_of(n), description)
    if (nrow(own) > 0) {
      entry <- c(entry, sprintf("    - %s()%s", own$function_name, ifelse(nzchar(own$title), paste0(": ", own$title), "")))
    }
    entry
  }))
  list(text = paste(lines, collapse = "\n"), names = keep, functions = sort(unique(offered$function_name)))
}
