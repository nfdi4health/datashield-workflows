# Adds the rules' proposal to every classified row (propose_ds_name()),
# makes each function's names distinct (resolve_naming_collisions()), then
# keeps client and server in lockstep: a server argument the client passes
# a renamed argument to (`links`) gets the client's new name, so both
# sides end up with the same one.
propose_naming_rows <- function(rows, links, rules) {
  # Server arguments mirroring a client one carry a suffix (exclude.transmit);
  # the rules apply to the name without it, the suffix is kept while
  # `server_transmit_suffix` is open (front-runner: keep).
  suffix <- rules$exceptions$server_transmit_suffix %||% ""
  with_suffix <- nzchar(suffix) & rows$side == "server" & endsWith(rows$arg, suffix)
  stem <- ifelse(with_suffix, substr(rows$arg, 1, nchar(rows$arg) - nchar(suffix)), rows$arg)
  proposals <- lapply(seq_len(nrow(rows)), function(i) {
    role <- rows$role[i]
    if (role == "unclear") {
      role <- "unknown"
    }
    p <- propose_ds_name(stem[i], role, rows$class[i], rows$package[i], rules)
    if (with_suffix[i]) {
      if (!is.na(p$proposed)) {
        p$proposed <- paste0(p$proposed, suffix)
      }
      if (identical(p$proposed, rows$arg[i])) {
        p$match <- if (p$match == "exception") {
        "exception"
      } else {
        "canonical"
      }
      }
    }
    p
  })
  rows$proposed <- vapply(proposals, function(p) as.character(p$proposed), character(1))
  rows$rule <- vapply(proposals, function(p) p$rule, character(1))
  rows$rule_open <- vapply(proposals, function(p) isTRUE(p$rule_open), logical(1))
  rows$match <- vapply(proposals, function(p) p$match, character(1))
  # Claude's reason, else what the classification rests on, e.g.
  # "data.frame object (doc)".
  what <- ifelse(rows$role == "object" & nzchar(rows$class), paste(rows$class, "object"),
                 ifelse(rows$role == "value" & nzchar(rows$class), paste(rows$class, "value"), gsub("_", " ", rows$role)))
  rule_reason <- vapply(proposals, function(p) p$reason %||% "", character(1))
  rows$reason <- ifelse(nzchar(rows$reason), rows$reason,
                        ifelse(nzchar(rule_reason), rule_reason, sprintf("%s (%s)", what, rows$evidence)))
  rows$note <- ""

  key <- paste(rows$package, rows$`function`)
  rows <- do.call(rbind, lapply(split(rows, factor(key, levels = unique(key))), resolve_naming_collisions, rules = rules))

  # A server function called by several client functions follows them only
  # if they agree, else the one named like it (ds.asFactor <-> asFactorDS1).
  base_name <- function(fn) tolower(sub("DS[0-9]*(\\..*)?$", "", sub("^ds\\.", "", fn)))
  for (key_pair in unique(paste(links$server_fn, links$server_arg))) {
    l <- links[paste(links$server_fn, links$server_arg) == key_pair, ]
    si <- which(rows$side == "server" & rows$`function` == l$server_fn[1] & rows$arg == l$server_arg[1])
    ci <- vapply(seq_len(nrow(l)), function(k) {
      i <- which(rows$side == "client" & rows$`function` == l$client_fn[k] & rows$arg == l$client_arg[k])
      if (length(i) == 1 && !is.na(rows$proposed[i]) && !rows$match[i] %in% c("exception", "conflict")) {
        i
      } else {
        NA_integer_
      }
    }, integer(1))
    keep <- !is.na(ci)
    l <- l[keep, ]; ci <- ci[keep]
    if (length(si) != 1 || length(ci) == 0) {
      next
    }
    if (length(unique(rows$proposed[ci])) > 1) {
      own <- ci[base_name(l$client_fn) == base_name(l$server_fn[1])]
      if (length(unique(rows$proposed[own])) != 1) {
        rows$note[si] <- sprintf("client callers differ: %s", paste(sprintf("%s(%s -> %s)", l$client_fn, l$client_arg, rows$proposed[ci]), collapse = ", "))
        next
      }
      l <- l[ci %in% own, ][1, ]
      ci <- own[1]
    } else {
      l <- l[1, ]
      ci <- ci[1]
    }
    wanted <- rows$proposed[ci]
    if (with_suffix[si]) {
      wanted <- paste0(wanted, suffix)
    }
    if (identical(rows$proposed[si], wanted)) {
      next
    }
    rows$proposed[si] <- wanted
    rows$rule[si] <- rows$rule[ci]
    rows$rule_open[si] <- rows$rule_open[ci]
    rows$match[si] <- if (rows$arg[si] == wanted) {
      "canonical"
    } else {
      "rule"
    }
    rows$note[si] <- sprintf("follows client %s(%s)", l$client_fn, l$client_arg)
  }
  # Following the client can make two server arguments collide.
  rows <- do.call(rbind, lapply(split(rows, factor(key, levels = unique(key))), resolve_naming_collisions, rules = rules))
  rownames(rows) <- NULL
  rows
}
