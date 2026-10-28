# Help titles of a package's topics, by alias (function name -> title).
rd_titles <- function(pkg) {
  db <- tryCatch(tools::Rd_db(pkg), error = function(e) list())
  titles <- list()
  for (rd in db) {
    tags <- vapply(rd, function(x) attr(x, "Rd_tag"), character(1))
    title <- paste(trimws(unlist(rd[tags == "\\title"])), collapse = " ")
    for (alias in unlist(rd[tags == "\\alias"])) {
      titles[[trimws(alias)]] <- title
    }
  }
  titles
}
