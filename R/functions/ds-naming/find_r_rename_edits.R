# Where in parsed R code (`lines`) the approved renames (`renames`: fn,
# old, new) apply, from R's parse data — never by text search:
#   - in the definition of `fn`: the formal `old` and every use of the
#     variable `old` in its body (not `x$old` / `x@old`);
#   - anywhere: calls `fn(old = ...)` / `pkg::fn(old = ...)`;
#   - `server_renames` (alias, old, new): server calls built as
#     call("alias", old = ...).
# Returns list(edits = data frame line, col, old, new; notes): notes are
# strings in the function's body that mention `old` (error messages),
# left for a person. NULL when the code doesn't parse.
find_r_rename_edits <- function(lines, renames, server_renames = NULL) {
  exprs <- tryCatch(parse(text = lines, keep.source = TRUE), error = function(e) NULL)
  if (is.null(exprs)) {
    return(NULL)
  }
  pd <- utils::getParseData(exprs, includeText = TRUE)
  empty <- data.frame(line = integer(0), col = integer(0), old = character(0), new = character(0))
  if (is.null(pd) || nrow(pd) == 0) {
    return(list(edits = empty, notes = character(0)))
  }
  pd <- pd[order(pd$line1, pd$col1), ]
  terminals <- pd[pd$terminal, ]
  edits <- list()
  notes <- character(0)
  add <- function(rows, old, new) {
    if (nrow(rows) > 0) {
      edits[[length(edits) + 1]] <<- data.frame(line = rows$line1, col = rows$col1, old = old, new = new)
    }
  }
  inside <- function(rows, span) {
    after_start <- rows$line1 > span$line1 | (rows$line1 == span$line1 & rows$col1 >= span$col1)
    before_end <- rows$line2 < span$line2 | (rows$line2 == span$line2 & rows$col2 <= span$col2)
    rows[after_start & before_end, ]
  }
  # The function a call expression calls: SYMBOL_FUNCTION_CALL in its first child.
  called <- function(call_id) {
    kids <- pd[pd$parent == call_id, ]
    if (nrow(kids) == 0) {
      return("")
    }
    f <- pd[pd$parent == kids$id[1] & pd$token == "SYMBOL_FUNCTION_CALL", "text"]
    if (length(f) == 1) {
      f
    } else {
      ""
    }
  }
  first_string_arg <- function(call_id) {
    kids <- pd[pd$parent == call_id & !pd$terminal, ]
    if (nrow(kids) < 2) {
      return("")
    }
    s <- pd[pd$parent == kids$id[2] & pd$token == "STR_CONST", "text"]
    if (length(s) == 1) {
      gsub("^[\"']|[\"']$", "", s)
    } else {
      ""
    }
  }

  # Definitions: <fn> <- function(...) / <fn> = function(...)
  assigns <- pd[pd$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN"), ]
  for (k in seq_len(nrow(assigns))) {
    kids <- pd[pd$parent == assigns$parent[k] & !pd$terminal, ]
    if (nrow(kids) != 2) {
      next
    }
    name <- pd[pd$parent == kids$id[1] & pd$token %in% c("SYMBOL", "STR_CONST"), "text"]
    fun <- pd[pd$parent == kids$id[2] & pd$token == "FUNCTION", ]
    if (length(name) != 1 || nrow(fun) != 1) {
      next
    }
    name <- gsub("^[\"'`]|[\"'`]$", "", name)
    for (r in which(renames$fn == name)) {
      old <- renames$old[r]
      span <- pd[pd$id == kids$id[2], ]
      body <- inside(terminals, span)
      add(body[body$token == "SYMBOL_FORMALS" & body$text == old & body$parent == kids$id[2], ], old, renames$new[r])
      sym <- body[body$token == "SYMBOL" & body$text == old, ]
      if (nrow(sym) > 0) {
        before <- vapply(seq_len(nrow(sym)), function(i) {
          prev <- terminals[terminals$line1 < sym$line1[i] | (terminals$line1 == sym$line1[i] & terminals$col1 < sym$col1[i]), ]
          if (nrow(prev) == 0) {
            ""
          } else {
            prev$token[nrow(prev)]
          }
        }, character(1))
        add(sym[!before %in% c("'$'", "'@'", "NS_GET", "NS_GET_INT"), ], old, renames$new[r])
      }
      strings <- body[body$token == "STR_CONST" & grepl(paste0("(?<![A-Za-z0-9._])", gsub("([.])", "\\\\\\1", old), "(?![A-Za-z0-9._])"), body$text, perl = TRUE), ]
      if (nrow(strings) > 0) {
        notes <- c(notes, sprintf("%s, line %d: a string mentions `%s`: %s", name, strings$line1, old, strings$text))
      }
    }
  }

  # Calls with a named argument: fn(old = ...), call("alias", old = ...)
  subs <- terminals[terminals$token == "SYMBOL_SUB", ]
  for (i in seq_len(nrow(subs))) {
    target <- called(subs$parent[i])
    if (!nzchar(target)) {
      next
    }
    r <- which(renames$fn == target & renames$old == subs$text[i])
    if (length(r) == 1) {
      add(subs[i, ], subs$text[i], renames$new[r])
    }
    if (target == "call" && !is.null(server_renames) && nrow(server_renames) > 0) {
      alias <- first_string_arg(subs$parent[i])
      r <- which(server_renames$alias == alias & server_renames$old == subs$text[i])
      if (length(r) == 1) {
        add(subs[i, ], subs$text[i], server_renames$new[r])
      }
    }
  }
  all_edits <- empty
  if (length(edits) > 0) {
    all_edits <- unique(do.call(rbind, edits))
  }
  list(edits = all_edits, notes = notes)
}
