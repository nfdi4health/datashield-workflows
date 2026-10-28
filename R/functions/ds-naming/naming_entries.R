# The transformation-file entries for the proposed rows: every argument
# the rules would rename, plus conflicts and unresolved ones (they need a
# person); arguments already right or exempt are only counted in the
# report. Keyed by id "<package>::<function>::<current name>"; `linked`
# lists the ids of the client/server counterparts (`links`).
naming_entries <- function(rows, links) {
  id_of <- function(pkg, fn, arg) paste(pkg, fn, arg, sep = "::")
  client_pkg <- unique(rows$package[rows$side == "client"])
  server_pkg <- unique(rows$package[rows$side == "server"])
  keep <- which(is.na(rows$proposed) | rows$match %in% c("rule", "alias", "style", "conflict"))
  entries <- lapply(keep, function(i) {
    r <- rows[i, ]
    linked <- if (r$side == "client") {
      l <- links[links$client_fn == r$`function` & links$client_arg == r$arg, ]
      if (length(server_pkg) == 1) {
        id_of(server_pkg, l$server_fn, l$server_arg)
      } else {
        character(0)
      }
    } else {
      l <- links[links$server_fn == r$`function` & links$server_arg == r$arg, ]
      if (length(client_pkg) == 1) {
        id_of(client_pkg, l$client_fn, l$client_arg)
      } else {
        character(0)
      }
    }
    # No proposal, or a conflict: left for a person to decide.
    if (is.na(r$proposed) || r$match == "conflict") {
      proposed <- ""
      status <- "unresolved"
    } else {
      proposed <- r$proposed
      status <- "proposed"
    }
    list(
      id = id_of(r$package, r$`function`, r$arg), package = r$package, side = r$side, `function` = r$`function`,
      current = r$arg, proposed = proposed,
      status = status,
      rule = r$rule, rule_open = r$rule_open, match = r$match, role = r$role, class = r$class,
      confidence = r$confidence, source = r$source, reason = r$reason, linked = as.list(unique(linked)), note = r$note
    )
  })
  stats::setNames(entries, vapply(entries, function(e) e$id, character(1)))
}
