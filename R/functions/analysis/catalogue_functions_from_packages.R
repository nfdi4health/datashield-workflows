# The client functions of the catalogue's packages.json (see
# read_function_catalogue()): per package (the key, e.g. dsBaseClient) its
# `repo$function_info$roxygen_tags`, one block per function
# ({function, tags: {title, description, _intro, ...}}, each tag a list of
# strings). Kept are "ds." names that aren't server functions (DS,
# DS1, DS.<suffix> endings); title is @title, else the first sentence of
# the text before the first tag, description @description, else the
# rest of it, one line each. A package whose `repo` or `function_info`
# is "Error" (the catalogue couldn't read it) has no functions. Returns a
# data frame (package, function_name, title, description).
catalogue_functions_from_packages <- function(packages) {
  one_line <- function(x) trimws(gsub("[[:space:]]+", " ", paste(unlist(x), collapse = " ")))
  rows <- lapply(names(packages), function(name) {
    repo <- if (is.list(packages[[name]]$repo)) packages[[name]]$repo else list()
    info <- if (is.list(repo$function_info)) repo$function_info else list()
    blocks <- info$roxygen_tags
    if (!is.list(blocks) || length(blocks) == 0) {
      return(NULL)
    }
    do.call(rbind, lapply(blocks, function(b) {
      fn <- b[["function"]]
      if (!is.character(fn) || length(fn) != 1 || !startsWith(fn, "ds.") || grepl("DS[0-9]*($|\\.)", fn)) {
        return(NULL)
      }
      tags <- if (is.list(b$tags)) b$tags else list()
      intro <- strsplit(one_line(tags[["_intro"]] %||% ""), "(?<=\\.)\\s+", perl = TRUE)[[1]]
      title <- one_line(tags$title %||% if (length(intro)) intro[1] else "")
      description <- one_line(tags$description %||% if (length(intro) > 1) paste(intro[-1], collapse = " ") else "")
      data.frame(package = name, function_name = fn, title = title, description = description)
    }))
  })
  out <- do.call(rbind, c(list(data.frame(package = character(0), function_name = character(0),
    title = character(0), description = character(0))), rows))
  out[!duplicated(paste(out$package, out$function_name)), , drop = FALSE]
}
