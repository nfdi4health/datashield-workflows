# Applies the renames (fn, old, new) to the roxygen comments of an R
# file: in the block of `fn` itself the @param name and mentions written
# as \code{old} or `old`; in every block, calls to `fn` in examples
# (rename_call_args_text()). Other prose is left alone — that is for the
# advisory vignette/prose step. Returns list(lines, done).
rename_in_roxygen <- function(lines, renames) {
  done <- 0
  rox <- grepl("^\\s*#'", lines)
  if (!any(rox)) {
    return(list(lines = lines, done = 0))
  }
  esc <- function(x) gsub("([.])", "\\\\\\1", x)

  for (r in seq_len(nrow(renames))) {
    fn <- renames$fn[r]; old <- renames$old[r]; new <- renames$new[r]
    def <- grep(paste0("^\\s*`?", esc(fn), "`?\\s*(<-|=)\\s*function\\b"), lines)
    for (d in def) {
      # the block: all #' lines above, blank lines in between allowed (as roxygen2 reads it)
      i <- d - 1
      while (i >= 1 && (rox[i] || !nzchar(trimws(lines[i])))) {
        i <- i - 1
      }
      block <- which(rox[seq_len(d - 1)] & seq_len(d - 1) > i)
      for (j in block) {
        before <- lines[j]
        if (grepl("^\\s*#'\\s*@param\\s", lines[j])) {
          m <- regmatches(lines[j], regexec("^(\\s*#'\\s*@param\\s+)(\\S+)(.*)$", lines[j]))[[1]]
          arg_names <- strsplit(m[3], ",")[[1]]
          arg_names[arg_names == old] <- new
          lines[j] <- paste0(m[2], paste(arg_names, collapse = ","), m[4])
        }
        lines[j] <- gsub(paste0("\\\\code\\{", esc(old), "\\}"), paste0("\\\\code{", new, "}"), lines[j])
        lines[j] <- gsub(paste0("`", esc(old), "`"), paste0("`", new, "`"), lines[j])
        if (!identical(before, lines[j])) {
          done <- done + 1
        }
      }
    }
    # examples anywhere in the file: strip the #' prefix so its quote
    # doesn't count as a string
    idx <- which(rox)
    prefix <- sub("^(\\s*#'\\s?).*$", "\\1", lines[idx])
    res <- rename_call_args_text(substring(lines[idx], nchar(prefix) + 1), fn, old, new)
    if (res$done > 0) {
      lines[idx] <- paste0(prefix, res$lines)
      done <- done + res$done
    }
  }
  list(lines = lines, done = done)
}
