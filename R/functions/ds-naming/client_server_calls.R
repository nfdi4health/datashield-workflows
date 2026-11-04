# The server methods a client package calls, from all its functions:
# call("meanDS", x), paste0("meanDS(", x, ")") and strings passed directly
# to datashield.aggregate() / datashield.assign*(), as in "lsDS()". Only
# names ending in DS (digits allowed) count, so that a paste0("sum(", ...)
# in a message isn't taken for one; `declared` names count as well, for
# methods with another alias. Returns a data frame client_fn, method.
client_server_calls <- function(client, declared = character(0)) {
  found <- list()
  note <- function(fn, name) {
    if (name %in% declared || grepl("DS[0-9]*$", name)) {
      found[[length(found) + 1]] <<- data.frame(client_fn = fn, method = name)
    }
  }
  called_name <- function(text) {
    sub("\\(.*$", "", text)
  }
  walk_code <- function(x, fn) {
    if (!is.call(x)) {
      return()
    }
    head <- tail(as.character(x[[1]]), 1)
    parts <- as.list(x)[-1]
    first <- if (length(parts) >= 1 && is.character(parts[[1]]) && length(parts[[1]]) == 1) {
      parts[[1]]
    } else {
      ""
    }
    if (identical(head, "call") && nzchar(first)) {
      note(fn, first)
    } else if (head %in% c("paste0", "paste") && grepl("\\($", first)) {
      note(fn, called_name(first))
    } else if (startsWith(head, "datashield.a")) {
      for (p in parts) {
        if (is.character(p) && length(p) == 1 && grepl("^[A-Za-z.][A-Za-z0-9._]*\\(", p)) {
          note(fn, called_name(p))
        }
      }
    }
    for (p in parts) {
      if (is.call(p)) {
        walk_code(p, fn)
      }
    }
  }
  for (d in client$defs) {
    expr <- tryCatch(parse(text = d$source, keep.source = FALSE)[[1]], error = function(e) NULL)
    if (!is.null(expr)) {
      walk_code(expr, d$name)
    }
  }
  if (length(found) == 0) {
    return(data.frame(client_fn = character(0), method = character(0)))
  }
  unique(do.call(rbind, found))
}
