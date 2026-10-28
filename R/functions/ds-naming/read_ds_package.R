# Reads one package source directory for the naming check: its name, the
# user-facing functions (client: NAMESPACE exports; server: the
# AggregateMethods/AssignMethods in DESCRIPTION, else its exports) and one
# row per argument of those (data frame), with its default and @param text
# (roxygen, else man/*.Rd). `defs` keeps every definition, user-facing or
# not, for the test-file and call checks.
read_ds_package <- function(pkg_dir, side) {
  name <- unname(read.dcf(file.path(pkg_dir, "DESCRIPTION"), fields = "Package")[1, 1])
  defs <- unlist(lapply(list.files(file.path(pkg_dir, "R"), pattern = "\\.[Rr]$", full.names = TRUE), read_r_definitions), recursive = FALSE)
  def_names <- vapply(defs, function(d) d$name, character(1))

  ns <- tryCatch(parseNamespaceFile(basename(normalizePath(pkg_dir)), dirname(normalizePath(pkg_dir)), mustExist = FALSE),
                 error = function(e) list(exports = character(0), exportPatterns = character(0)))
  exports <- union(ns$exports, unlist(lapply(ns$exportPatterns, function(p) grep(p, def_names, value = TRUE))))
  methods <- if (side == "server") {
    read_description_methods(pkg_dir)
  } else {
    character(0)
  }
  user_facing <- if (side == "server" && length(methods) > 0) {
    unique(unname(methods))
  } else {
    exports
  }

  rd_docs <- rd_param_docs(file.path(pkg_dir, "man"))
  rows <- list()
  for (d in defs[!duplicated(def_names) & def_names %in% user_facing]) {
    for (k in seq_along(d$args)) {
      a <- d$args[k]
      doc <- d$param_docs[[a]] %||% ""
      doc_source <- if (nzchar(doc)) {
        "roxygen"
      } else {
        ""
      }
      if (!nzchar(doc)) {
        doc <- rd_docs[[d$name]][[a]] %||% ""
        if (nzchar(doc)) {
          doc_source <- "Rd"
        }
      }
      rows[[length(rows) + 1]] <- data.frame(
        package = name, side = side, `function` = d$name, file = sub(paste0("^", normalizePath(pkg_dir, "/"), "/"), "", normalizePath(d$file, "/")),
        line = d$line, position = k, n_args = length(d$args), arg = a, default = d$defaults[k],
        doc = doc, doc_source = doc_source, check.names = FALSE, stringsAsFactors = FALSE
      )
    }
  }
  args <- if (length(rows) > 0) {
    do.call(rbind, rows)
  } else {
    data.frame()
  }
  list(name = name, side = side, dir = pkg_dir, defs = defs, exports = exports, methods = methods,
       user_facing = intersect(user_facing, def_names), args = args)
}
