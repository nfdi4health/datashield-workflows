# Merges one function's findings of this run into the state the test bot
# PR carries (decode_suggestion_state()), so its description stays one
# report instead of growing an update per run. Each entry: id, kind ("new",
# "updated", "deleted", "note" = existing test to look at, "bug" = possible
# bug in the code, "failed" = generated test that failed, "setup",
# "dependency" = package added to Suggests (description = its name),
# "untested"), fn, file, description, reason, explanation, classification,
# in_report, origin and confidence and issue (bugs: "existing" = a
# reported existing test, "failure" = a failed generated test, with the
# URL of its issue if one was opened), sha, code (code_fingerprint() of
# the function), choice (the user's checkbox, record_suggestion_choices()),
# status ("active",
# "superseded", "resolved"), status_sha, status_note. Entries are never
# deleted, only crossed out, in this order:
# 1. a test file the user changed since the last review: the bot's earlier
#    entries for it gave way to their version;
# 2. Claude judged an earlier note, bug or failure superseded or resolved
#    (`run$decisions`) — only this function's: ids are plain strings in the
#    tool schema (it stays the same across functions, for the prompt
#    cache), so an id of another function's finding is ignored, as in 6;
# 3. an earlier note or bug about an existing test that passes now, or no
#    longer exists, is resolved (`run$current`: this run's results before
#    any change, as list(file, description, passed));
# 4. a new test resolves an earlier failure (or bug found by one) it
#    repeats (by id or name);
# 5. an update or deletion replaces earlier entries on that test;
# 6. a possible bug on a test with an open bug is skipped, and replaces an
#    open plain note on it; a note on a test with an open note or bug is
#    skipped (by id, or same file and test);
# 7. failures (already without repeats, see R/suggest_tests.R), created
#    setup files and an untested function are added — the last two once.
# Returns list(state, stats: new, crossed, repeats).
merge_test_findings <- function(state, fn, run, sha) {
  entries <- state$entries
  next_id <- state$next_id
  stats <- c(new = 0L, crossed = 0L, repeats = as.integer(run$repeats %||% 0L))
  text <- function(x) {
    x %||% ""
  }

  is_open <- function(e, kinds) identical(e$status, "active") && isTRUE(e$kind %in% kinds)
  cross <- function(keep, status, note) {
    for (i in seq_along(entries)) {
      if (keep(entries[[i]])) {
        entries[[i]]$status <<- status
        entries[[i]]$status_sha <<- sha
        entries[[i]]$status_note <<- note
        stats[["crossed"]] <<- stats[["crossed"]] + 1L
      }
    }
  }
  add <- function(kind, fields) {
    blank <- list(file = "", description = "", reason = "", explanation = "", classification = "", in_report = FALSE,
                  origin = "", confidence = "", issue = "")
    entries[[length(entries) + 1]] <<- c(
      list(id = next_id, kind = kind, fn = fn),
      modifyList(blank, fields),
      list(sha = sha, code = run$code %||% "", status = "active", status_sha = "", status_note = "")
    )
    next_id <<- next_id + 1L
    stats[["new"]] <<- stats[["new"]] + 1L
  }
  id_of <- function(label) {
    if (is.null(label) || !nzchar(label)) {
      return(NA_integer_)
    }
    suppressWarnings(as.integer(sub("^E", "", label)))
  }
  same_test <- function(e, file, description) identical(e$file, file) && identical(e$description, description)

  if (length(run$user_edited) > 0) {
    cross(function(e) is_open(e, c("new", "updated", "deleted", "note")) && e$file %in% run$user_edited,
          "superseded", "replaced by your own edit of this file")
  }

  for (d in run$decisions) {
    if (!isTRUE(d$status %in% c("superseded", "resolved"))) {
      next
    }
    id <- id_of(d$id)
    cross(function(e) is_open(e, c("note", "bug", "failed")) && identical(e$fn, fn) && identical(as.integer(e$id), id), d$status, text(d$note))
  }

  # A file that produced no results at all (it didn't run) proves nothing.
  ran <- unique(vapply(run$current, function(r) r$file, character(1)))
  about_existing <- function(e) is_open(e, "note") || (is_open(e, "bug") && identical(e$origin, "existing"))
  for (e in Filter(function(e) about_existing(e) && identical(e$fn, fn), entries)) {
    now <- Find(function(r) same_test(r, e$file, e$description), run$current)
    if (is.null(now) && (e$file %in% ran || !file.exists(e$file))) {
      cross(function(x) identical(x$id, e$id) && about_existing(x), "resolved", "the test no longer exists")
    } else if (isTRUE(now$passed)) {
      cross(function(x) identical(x$id, e$id) && about_existing(x), "resolved", "the test passes now")
    }
  }

  for (t in run$new) {
    id <- id_of(t$repeats_earlier)
    cross(function(e) (is_open(e, "failed") || (is_open(e, "bug") && identical(e$origin, "failure"))) && identical(e$fn, fn) &&
            (identical(as.integer(e$id), id) || identical(e$description, t$description)),
          "resolved", "a new version of the test passes")
    add("new", list(file = t$file, description = t$description, reason = t$reason))
  }

  for (ch in run$changes) {
    cross(function(e) (is_open(e, c("new", "updated", "note")) || (is_open(e, "bug") && identical(e$origin, "existing"))) && same_test(e, ch$file, ch$description),
          "superseded", sprintf("%s by a later review", ch$action))
    add(ch$action, list(file = ch$file, description = ch$description, reason = ch$reason, explanation = text(ch$explanation)))
  }

  # Same earlier finding: by the id Claude gave, or the same file and test.
  repeats <- function(x, kinds) {
    id <- id_of(x$repeats_earlier)
    any(vapply(entries, function(e) is_open(e, kinds) && ((identical(e$fn, fn) && identical(as.integer(e$id), id)) || same_test(e, x$file, x$description)), logical(1)))
  }

  for (b in run$bugs) {
    if (identical(b$origin, "existing") && repeats(b, "bug")) {
      stats[["repeats"]] <- stats[["repeats"]] + 1L
      next
    }
    if (identical(b$origin, "existing")) {
      cross(function(e) is_open(e, "note") && same_test(e, b$file, b$description), "superseded", "reported as a possible bug in the code")
    }
    add("bug", list(file = b$file, description = b$description, explanation = text(b$explanation),
                    origin = b$origin, confidence = text(b$confidence), issue = text(b$issue)))
  }

  for (n in run$notes) {
    if (repeats(n, c("note", "bug"))) {
      stats[["repeats"]] <- stats[["repeats"]] + 1L
      next
    }
    add("note", list(file = n$file, description = n$description, explanation = text(n$text)))
  }

  for (f in run$failed) {
    add("failed", list(file = f$file, description = f$description, classification = f$classification,
                       explanation = text(f$explanation), in_report = isTRUE(f$in_report)))
  }

  for (path in run$setups) {
    if (!any(vapply(entries, function(e) is_open(e, "setup") && identical(e$file, path), logical(1)))) {
      add("setup", list(file = path))
    }
  }

  for (pkg in run$dependencies) {
    if (!any(vapply(entries, function(e) is_open(e, "dependency") && identical(e$description, pkg), logical(1)))) {
      add("dependency", list(file = "DESCRIPTION", description = pkg))
    }
  }

  if (!is.null(run$untested)) {
    if (!any(vapply(entries, function(e) is_open(e, "untested") && identical(e$file, run$untested), logical(1)))) {
      add("untested", list(file = run$untested, description = fn))
    }
  }

  state$entries <- entries
  state$next_id <- next_id
  list(state = state, stats = stats)
}
