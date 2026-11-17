# A method's (or variant's) "Exists in DataSHIELD?" verdict as the report
# shows it: the verdict with its function; `development` reads as "no",
# with the development package's function as a note (not counted as
# existing, user 2026-11-16); "–" while not checked.
exists_label <- function(vocab, method, variant = "") {
  m <- vocab$methods[[method]]
  rec <- if (nzchar(variant)) m$variants[[variant]]$exists else m$exists
  if (is.null(rec)) return("–")
  fn <- rec[["function"]] %||% ""
  switch(rec$verdict,
    yes = sprintf("yes (`%s`)", fn),
    partial = sprintf("partly (`%s`)", fn),
    development = sprintf("no (in development: `%s`)", fn),
    none = "no",
    unclear = "unclear",
    unconfirmed = "unconfirmed",
    rec$verdict)
}
