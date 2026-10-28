# Merges one reviewed file's findings of this run into the state the bot PR
# carries (decode_suggestion_state()), so its description stays one report
# instead of growing an update per run. Each entry: id, file, kind
# ("applied", "dropped" = not applied, "bug"), field, reason, explanation,
# proposed, summary, confidence, sha (the reviewed commit it came from),
# code (code_fingerprint() of the function), choice (the user's checkbox,
# record_suggestion_choices()),
# status ("active", "superseded", "resolved"), status_sha, status_note.
# Entries are never deleted, only crossed out, in this order:
# 1. the user edited this documentation since the last review: the bot's
#    earlier applied changes gave way to theirs;
# 2. Claude judged an earlier finding superseded or resolved
#    (`run$decisions`, its earlier_findings);
# 3. a new applied change replaces earlier entries on the same field;
# 4. a new not-applied suggestion that repeats an open earlier one
#    (repeats_earlier) is skipped; otherwise it replaces earlier not-applied
#    suggestions on the same field;
# 5. a possible bug that repeats an open earlier one is skipped.
# `run` = list(applied, dropped, bugs, decisions). Returns list(state,
# stats: new, crossed, repeats).
merge_roxygen_findings <- function(state, path, run, sha, user_edited = FALSE) {
  entries <- state$entries
  next_id <- state$next_id
  stats <- c(new = 0L, crossed = 0L, repeats = 0L)

  is_open <- function(e, kinds) identical(e$file, path) && identical(e$status, "active") && isTRUE(e$kind %in% kinds)
  cross <- function(i, status, note) {
    entries[[i]]$status <<- status
    entries[[i]]$status_sha <<- sha
    entries[[i]]$status_note <<- note
    stats[["crossed"]] <<- stats[["crossed"]] + 1L
  }
  cross_where <- function(kinds, keep, status, note) {
    for (i in seq_along(entries)) {
      if (is_open(entries[[i]], kinds) && keep(entries[[i]])) {
      cross(i, status, note)
    }
    }
  }
  add <- function(kind, fields) {
    blank <- list(field = "", reason = "", explanation = "", proposed = "", summary = "", confidence = "")
    entries[[length(entries) + 1]] <<- c(
      list(id = next_id, file = path, kind = kind),
      modifyList(blank, fields),
      list(sha = sha, code = run$code %||% "", status = "active", status_sha = "", status_note = "")
    )
    next_id <<- next_id + 1L
    stats[["new"]] <<- stats[["new"]] + 1L
  }
  # TRUE if `label` (e.g. "E3") names an open earlier entry of `kind`.
  repeats <- function(label, kind) {
    if (is.null(label) || !nzchar(label)) {
      return(FALSE)
    }
    id <- suppressWarnings(as.integer(sub("^E", "", label)))
    hit <- Find(function(e) identical(as.integer(e$id), id), entries)
    !is.null(hit) && is_open(hit, kind)
  }
  text <- function(x) {
    x %||% ""
  }

  if (isTRUE(user_edited)) {
    cross_where("applied", function(e) TRUE, "superseded", "replaced by your own edit of this documentation")
  }

  for (d in run$decisions) {
    if (!isTRUE(d$status %in% c("superseded", "resolved"))) {
      next
    }
    id <- suppressWarnings(as.integer(sub("^E", "", d$id)))
    cross_where(c("dropped", "bug"), function(e) identical(as.integer(e$id), id), d$status, text(d$note))
  }

  for (ch in run$applied) {
    cross_where(c("applied", "dropped"), function(e) identical(e$field, ch$field), "superseded", sprintf("replaced by a newer change to `%s`", ch$field))
    add("applied", list(field = ch$field, reason = ch$reason, explanation = text(ch$explanation), proposed = text(ch$proposed)))
  }

  for (ch in run$dropped) {
    if (repeats(ch$repeats_earlier, "dropped")) {
      stats[["repeats"]] <- stats[["repeats"]] + 1L
      next
    }
    cross_where("dropped", function(e) identical(e$field, ch$field), "superseded", sprintf("replaced by a newer suggestion for `%s`", ch$field))
    add("dropped", list(field = ch$field, reason = ch$reason, explanation = text(ch$explanation), proposed = text(ch$proposed)))
  }

  for (b in run$bugs) {
    if (repeats(b$repeats_earlier, "bug")) {
      stats[["repeats"]] <- stats[["repeats"]] + 1L
      next
    }
    add("bug", list(summary = text(b$summary), explanation = text(b$explanation), confidence = text(b$confidence)))
  }

  state$entries <- entries
  state$next_id <- next_id
  list(state = state, stats = stats)
}
