# Argument texts from a package's man/*.Rd files, as the fallback for
# functions without roxygen @param: a list function name -> argument ->
# plain text, for every \alias of each file.
rd_param_docs <- function(man_dir) {
  out <- list()
  if (!dir.exists(man_dir)) {
    return(out)
  }
  rd_text <- function(x) trimws(gsub("\\s+", " ", paste(unlist(x), collapse = "")))
  for (f in list.files(man_dir, pattern = "\\.Rd$", full.names = TRUE)) {
    rd <- tryCatch(tools::parse_Rd(f), error = function(e) NULL, warning = function(w) NULL)
    if (is.null(rd)) {
      next
    }
    tags <- vapply(rd, function(x) attr(x, "Rd_tag") %||% "", character(1))
    aliases <- vapply(rd[tags == "\\alias"], rd_text, character(1))
    arguments <- rd[tags == "\\arguments"]
    if (length(arguments) == 0 || length(aliases) == 0) {
      next
    }
    params <- list()
    for (item in arguments[[1]]) {
      if (!identical(attr(item, "Rd_tag"), "\\item") || length(item) < 2) {
        next
      }
      for (nm in trimws(strsplit(rd_text(item[[1]]), ",")[[1]])) {
        params[[nm]] <- rd_text(item[[2]])
      }
    }
    for (a in aliases) {
      out[[a]] <- params
    }
  }
  out
}
