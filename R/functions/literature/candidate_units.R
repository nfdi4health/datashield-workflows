# What can be a candidate: methods whose "Exists in DataSHIELD?" verdict
# is `none` or `partial`, and variants with such a verdict of a method
# DataSHIELD has in some form (a variant of a missing method is covered by
# the method). `development` doesn't count (user, 2026-11-16). A data
# frame of key ("method" or "method/variant"), method, variant, verdict,
# function and note.
candidate_units <- function(vocab) {
  gap <- c("none", "partial")
  rows <- list()
  add <- function(method, variant, rec) {
    rows[[length(rows) + 1]] <<- data.frame(key = if (nzchar(variant)) paste(method, variant, sep = "/") else method,
      method = method, variant = variant, verdict = rec$verdict, `function` = rec[["function"]] %||% "",
      note = rec$note %||% "", check.names = FALSE)
  }
  for (method in names(vocab$methods)) {
    m <- vocab$methods[[method]]
    if (!is.null(m$exists) && m$exists$verdict %in% gap) add(method, "", m$exists)
    if (!is.null(m$exists) && m$exists$verdict == "none") next
    for (variant in names(m$variants)) {
      rec <- m$variants[[variant]]$exists
      if (!is.null(rec) && rec$verdict %in% gap) add(method, variant, rec)
    }
  }
  do.call(rbind, c(list(data.frame(key = character(0), method = character(0), variant = character(0),
    verdict = character(0), `function` = character(0), note = character(0), check.names = FALSE)), rows))
}
