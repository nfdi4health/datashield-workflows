# One "Exists?" answer as it is stored: a `yes` or `partial` needs a
# function among the method's candidates and a quote that occurs in that
# function's title or description (case and spacing ignored), else the
# verdict becomes `unconfirmed`. A match in a package whose status is
# development becomes `development` (not counted as existing; the match
# is kept). `candidates` is the hash the verdict is valid for.
check_exists_answer <- function(answer, candidates, hash, today, by) {
  squash <- function(x) gsub("[[:space:]]+", " ", tolower(trimws(x)))
  rec <- list(verdict = answer$verdict, `function` = "", quote = "", note = answer$note %||% "",
    checked = as.character(today), candidates = hash, by = by)
  if (answer$verdict %in% c("yes", "partial")) {
    ids <- paste(candidates$package, candidates$fn, sep = "::")
    i <- match(answer[["function"]] %||% "", ids)
    doc <- if (is.na(i)) "" else squash(paste(candidates$title[i], candidates$description[i], sep = " \n "))
    quote <- squash(answer$quote %||% "")
    if (is.na(i) || !nzchar(quote) || !grepl(quote, doc, fixed = TRUE)) {
      rec$verdict <- "unconfirmed"
      rec$note <- trimws(paste(rec$note, sprintf("(Claude said %s, but the function or its quote wasn't found.)", answer$verdict)))
      return(rec)
    }
    rec[["function"]] <- ids[i]
    rec$quote <- answer$quote
    if (identical(candidates$status[i], "development")) {
      rec$match <- answer$verdict
      rec$verdict <- "development"
    }
  }
  rec
}
