# Writes the months of the register that changed (reg$dirty), each file in
# full, papers ordered by PubMed ID so a re-run doesn't reorder lines.
write_register <- function(reg, dir) {
  for (month in unique(reg$dirty)) {
    recs <- Filter(function(r) identical(r$month, month), reg$papers)
    recs <- recs[order(suppressWarnings(as.numeric(names(recs))), names(recs))]
    path <- register_file(dir, month)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    lines <- vapply(recs, function(r) as.character(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null")), character(1))
    writeLines(enc2utf8(unname(lines)), path, useBytes = TRUE)
  }
  reg$dirty <- character(0)
  invisible(reg)
}
