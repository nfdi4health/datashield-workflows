# Functions whose `datasources` argument (role connection) is not last,
# with only `...` allowed after it (`order` in the rules). `rows` are the
# classified argument rows of one package. Report only: reordering breaks
# positional calls and is left to the maintainers.
check_argument_order <- function(rows, rules) {
  if (!isTRUE(rules$order$datasources_last) || nrow(rows) == 0) {
    return(character(0))
  }
  bad <- character(0)
  for (fn in unique(rows$`function`)) {
    r <- rows[rows$`function` == fn, ]
    conn <- which(r$role == "connection")
    if (length(conn) == 0) {
      next
    }
    after <- r$arg[seq_len(nrow(r)) > max(conn)]
    allowed_after <- character(0)
    if (isTRUE(rules$order$dots_after_datasources)) {
      allowed_after <- "..."
    }
    if (length(setdiff(after, allowed_after)) > 0) {
      bad <- c(bad, fn)
    }
  }
  bad
}
