# The approved entries of one package (`pkg`, read_ds_package()) as a
# data frame id, fn, old, new — checked against the code first: an entry
# whose argument is gone is already done (`done`), one whose new name the
# function already has for another, kept argument is a conflict
# (`conflicts`, not renamed), and one whose function doesn't exist is
# reported (`missing`). Swaps (a -> b, b -> a) are fine: all edits of a
# run are made on the original text.
approved_renames <- function(entries, pkg) {
  sel <- Filter(function(e) identical(e$status, "approved") && identical(e$package, pkg$name) && nzchar(e$proposed %||% ""), entries)
  formals <- stats::setNames(lapply(pkg$defs, function(d) d$args), vapply(pkg$defs, function(d) d$name, character(1)))
  renames <- data.frame(id = character(0), fn = character(0), old = character(0), new = character(0))
  done <- character(0); conflicts <- character(0); missing <- character(0)
  for (e in sel) {
    args <- formals[[e$`function`]]
    if (is.null(args)) { missing <- c(missing, e$id); next }
    if (!e$current %in% args) { if (e$proposed %in% args) {
      done <- c(done, e$id)
    } else {
      missing <- c(missing, e$id)
    }; next }
    renames <- rbind(renames, data.frame(id = e$id, fn = e$`function`, old = e$current, new = e$proposed))
  }
  for (i in seq_len(nrow(renames))) {
    args <- formals[[renames$fn[i]]]
    staying <- setdiff(args, renames$old[renames$fn == renames$fn[i]])
    final <- c(staying, renames$new[renames$fn == renames$fn[i]])
    if (renames$new[i] %in% staying || sum(final == renames$new[i]) > 1) {
      conflicts <- c(conflicts, renames$id[i])
    }
  }
  list(renames = renames[!renames$id %in% conflicts, ], done = done, conflicts = conflicts, missing = missing)
}
