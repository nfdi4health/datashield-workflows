# Which client argument is passed to which server argument: walks each
# user-facing client function's code for server calls built as
# call("meanDS", x, ...) or paste0("meanDS(", x, ",", y, ")") and pairs
# the client formals passed there with the server function's formals (by
# name if named, else by position; as.symbol()/as.name() unwrapped).
# Returns a data frame client_fn, client_arg, server_fn, server_arg — the
# pairs that are renamed in lockstep. Server functions called only some
# other way get no pairs (the check falls back to equal names).
link_server_calls <- function(client, server) {
  empty <- data.frame(client_fn = character(0), client_arg = character(0), server_fn = character(0), server_arg = character(0))
  if (is.null(server) || length(server$methods) == 0) {
    return(empty)
  }
  server_formals <- lapply(stats::setNames(server$defs, vapply(server$defs, function(d) d$name, character(1))), function(d) d$args)
  pairs <- list()

  add_pairs <- function(fn, client_args, alias, passed) {
    target <- server$methods[[alias]]
    formals <- server_formals[[target]]
    if (is.null(formals)) {
      return()
    }
    for (i in seq_along(passed)) {
      # an empty argument, as in x[, 1]
      if (is.name(passed[[i]]) && !nzchar(as.character(passed[[i]]))) {
        next
      }
      p <- passed[[i]]
      while (is.call(p) && as.character(p[[1]])[1] %in% c("as.symbol", "as.name") && length(p) == 2) {
        p <- p[[2]]
      }
      if (!is.name(p) || !as.character(p) %in% client_args) {
        next
      }
      server_arg <- if (nzchar(names(passed)[i] %||% "")) {
        names(passed)[i]
      } else if (i <= length(formals)) {
        formals[i]
      } else {
        NA
      }
      if (is.na(server_arg) || server_arg == "...") {
        next
      }
      pairs[[length(pairs) + 1]] <<- data.frame(client_fn = fn, client_arg = as.character(p), server_fn = target, server_arg = server_arg)
    }
  }
  walk_code <- function(x, fn, client_args) {
    if (!is.call(x)) {
      return()
    }
    head <- as.character(x[[1]])[1]
    parts <- as.list(x)[-1]
    if (identical(head, "call") && length(parts) >= 1 && is.character(parts[[1]]) && parts[[1]] %in% names(server$methods)) {
      add_pairs(fn, client_args, parts[[1]], parts[-1])
    } else if (head %in% c("paste0", "paste") && length(parts) >= 1 && is.character(parts[[1]])) {
      alias <- sub("\\($", "", parts[[1]])
      if (grepl("\\($", parts[[1]]) && alias %in% names(server$methods)) {
        add_pairs(fn, client_args, alias, Filter(function(p) !is.character(p), parts[-1]))
      }
    }
    for (i in seq_along(parts)) {
      if (is.call(parts[[i]])) {
      walk_code(parts[[i]], fn, client_args)
    }
    }
  }

  for (d in client$defs) {
    if (!d$name %in% client$user_facing) {
      next
    }
    expr <- tryCatch(parse(text = d$source, keep.source = FALSE)[[1]], error = function(e) NULL)
    if (is.null(expr)) {
      next
    }
    walk_code(expr[[3]][[3]], d$name, d$args)
  }
  if (length(pairs) == 0) {
    return(empty)
  }
  unique(do.call(rbind, pairs))
}
