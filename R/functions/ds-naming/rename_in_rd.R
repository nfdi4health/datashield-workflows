# Applies the renames (fn, old, new) to an Rd file, so the package checks
# cleanly before its docs are regenerated: in the Rd of `fn` (\alias) the
# \item{old} in \arguments, `old` in the \usage of fn( ... ) and
# \code{old}; in any Rd, calls to `fn` anywhere (examples and text).
# Returns list(lines, done).
rename_in_rd <- function(lines, renames) {
  done <- 0
  esc <- function(x) gsub("([.])", "\\\\\\1", x)
  aliases <- sub("^\\\\alias\\{(.*)\\}\\s*$", "\\1", grep("^\\\\alias\\{", lines, value = TRUE))
  for (r in seq_len(nrow(renames))) {
    fn <- renames$fn[r]; old <- renames$old[r]; new <- renames$new[r]
    if (fn %in% aliases) {
      before <- lines
      items <- grep("^\\s*\\\\item\\{", lines)
      for (j in items) {
        m <- regmatches(lines[j], regexec("^(\\s*\\\\item\\{)([^}]*)(\\}.*)$", lines[j]))[[1]]
        if (length(m) == 0) {
          next
        }
        arg_names <- trimws(strsplit(m[3], ",")[[1]])
        if (!old %in% arg_names) {
          next
        }
        arg_names[arg_names == old] <- new
        lines[j] <- paste0(m[2], paste(arg_names, collapse = ","), m[4])
      }
      lines <- gsub(paste0("\\\\code\\{", esc(old), "\\}"), paste0("\\\\code{", new, "}"), lines)
      usage <- grep("^\\\\usage\\{", lines)
      if (length(usage) == 1) {
        end <- usage + which(grepl("^\\}", lines[-(1:usage)]))[1]
        if (!is.na(end)) {
          res <- rename_call_args_text(lines[usage:end], fn, old, new, formals = TRUE)
          lines[usage:end] <- res$lines
        }
      }
      done <- done + sum(before != lines)
    }
    # calls anywhere in the file (examples, \code{fn(old = 1)} in the
    # text), as roxygen will write them from the renamed source
    res <- rename_call_args_text(lines, fn, old, new)
    lines <- res$lines
    done <- done + res$done
  }
  list(lines = lines, done = done)
}
