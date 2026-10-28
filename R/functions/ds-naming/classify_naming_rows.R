# One row per user-facing argument of the packages read (`pkgs`, a list
# of read_ds_package() results), classified by classify_ds_argument().
# A server argument the code can't place takes the classification of the
# client argument passed to it (`links`, link_server_calls()) — server
# functions are rarely documented, their client counterparts are.
classify_naming_rows <- function(pkgs, links) {
  rows <- do.call(rbind, lapply(pkgs, function(p) p$args))
  if (is.null(rows) || nrow(rows) == 0) {
    stop("No user-facing functions found to check.", call. = FALSE)
  }
  cls <- lapply(seq_len(nrow(rows)), function(i) classify_ds_argument(rows$arg[i], rows$default[i], rows$doc[i]))
  rows$role <- vapply(cls, function(x) x$role, character(1))
  rows$class <- vapply(cls, function(x) x$class, character(1))
  rows$confidence <- vapply(cls, function(x) x$confidence, character(1))
  rows$evidence <- vapply(cls, function(x) x$evidence, character(1))
  rows$source <- "rules"
  rows$reason <- ""

  for (i in which(rows$side == "server" & rows$confidence == "low")) {
    pair <- links[links$server_fn == rows$`function`[i] & links$server_arg == rows$arg[i], ]
    for (k in seq_len(nrow(pair))) {
      j <- which(rows$side == "client" & rows$`function` == pair$client_fn[k] & rows$arg == pair$client_arg[k])
      if (length(j) == 1 && rows$confidence[j] != "low") {
        rows[i, c("role", "class")] <- rows[j, c("role", "class")]
        rows$confidence[i] <- "medium"
        rows$evidence[i] <- sprintf("from client %s(%s)", pair$client_fn[k], pair$client_arg[k])
        break
      }
    }
  }
  rows
}
