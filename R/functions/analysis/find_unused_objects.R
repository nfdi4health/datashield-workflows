# Objects the bot's scripts create but no script uses, per file: server-side
# objects (the string given as `newobj` / `newobj.name`) whose name appears
# in no other string of any script, and R objects assigned at the top
# level whose name appears in no other expression. A bare top-level line
# that only prints an object (`x`, `x$y`, `print(x)`) doesn't count as a
# use, nor does an unassigned top-level call of an `inspection` function
# (settings$inspection_functions, e.g. ds.levels("x")). Runs over all
# scripts at the end, since a later step may use what an earlier one
# creates. `files` are the scripts' paths; returns a named list (file ->
# object names), only files with any.
find_unused_objects <- function(files, inspection = character(0)) {
  parsed <- lapply(setNames(files, files), function(f) {
    tryCatch(parse(file = f, keep.source = FALSE), error = function(e) expression())
  })
  is_print_only <- function(e) {
    is.name(e) || (is.call(e) && as.character(e[[1]])[1] %in% c("$", "[[", "print") && is.name(e[[2]])) ||
      (is.call(e) && is.name(e[[1]]) && as.character(e[[1]]) %in% inspection)
  }
  strings <- character(0)      # every string constant, with where it was created
  created_server <- list()     # file -> newobj names
  created_client <- list()     # file -> assigned names
  used_symbols <- character(0)
  walk <- function(x, file, arg, top) {
    if (is.character(x) && length(x) == 1) {
      if (arg %in% c("newobj", "newobj.name")) {
        created_server[[file]] <<- c(created_server[[file]], x)
      } else {
        strings <<- c(strings, x)
      }
      return()
    }
    if (is.name(x)) {
      used_symbols <<- c(used_symbols, as.character(x))
      return()
    }
    if (!is.call(x)) {
      return()
    }
    args <- as.list(x)
    nms <- names(args) %||% rep("", length(args))
    for (i in seq_along(args)[-1]) {
      if (!identical(args[[i]], quote(expr = ))) {
        walk(args[[i]], file, nms[i], FALSE)
      }
    }
    if (is.name(args[[1]])) {
      used_symbols <<- c(used_symbols, as.character(args[[1]]))
    } else {
      walk(args[[1]], file, "", FALSE)
    }
  }
  for (f in names(parsed)) {
    for (e in parsed[[f]]) {
      if (is_print_only(e)) {
        next
      }
      if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=", "<<-") && is.name(e[[2]])) {
        created_client[[f]] <- c(created_client[[f]], as.character(e[[2]]))
        walk(e[[3]], f, "", TRUE)
      } else {
        walk(e, f, "", TRUE)
      }
    }
  }
  # A server object is used when another string names it, alone or as
  # "name$column", or inside a formula or expression string.
  server_used <- function(name) {
    any(grepl(sprintf("(^|[^A-Za-z0-9._])%s([^A-Za-z0-9._]|$)", gsub(".", "\\.", name, fixed = TRUE)), strings))
  }
  out <- list()
  for (f in files) {
    unused <- c(Filter(Negate(server_used), unique(created_server[[f]])),
      setdiff(unique(created_client[[f]]), used_symbols))
    if (length(unused) > 0) {
      out[[f]] <- unused
    }
  }
  out
}
