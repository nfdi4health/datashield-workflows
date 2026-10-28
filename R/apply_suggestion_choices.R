#!/usr/bin/env Rscript
# Applies the user's checkbox choices in a roxygen or test bot PR
# (dev-notes/suggestion-choices.md): run by suggestion-choices.yml when a
# person edits the bot PR's description, in a checkout of the bot branch.
# For every finding that is a choice (suggestion_choice()), the files are
# made to match its box — checking what they contain, so the order of
# this and a bot run doesn't matter (apply_test_choice(),
# apply_roxygen_choice()). No Claude call. Writes
#   updated_files.txt — the files changed or removed, for the commit;
#   new_body.md       — the description with the boxes as applied (a
#                       choice that can't be applied is unticked again,
#                       with a note), if anything changed.
#
# Env: KIND ("tests" or "docs", from the bot branch name), BASE_REF (the
# base branch as fetched, e.g. origin/dev), PR_BODY_FILE (the description
# as edited).

library(jsonlite)

functions_dir <- if (dir.exists("R/functions")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
for (dir in c("shared", "tests", "roxygen", "choices")) {
  for (f in list.files(file.path(functions_dir, dir), pattern = "\\.R$", full.names = TRUE)) {
    source(f)
  }
}

kind <- Sys.getenv("KIND")
base_ref <- Sys.getenv("BASE_REF")
if (!kind %in% c("tests", "docs")) {
  stop("KIND must be \"tests\" or \"docs\", not \"", kind, "\".")
}
body <- paste(readLines(Sys.getenv("PR_BODY_FILE"), warn = FALSE), collapse = "\n")

state <- decode_suggestion_state(body)
choices <- read_suggestion_choices(body)
before <- state
state <- record_suggestion_choices(state, choices)
# The boxes the user just changed (the stored state still has the previous
# ones): their groups stay expanded in the rebuilt description, so the
# group they're working in doesn't collapse under them.
just_changed <- vapply(seq_along(state$entries), function(i) {
  !identical(suggestion_choice(before$entries[[i]]), suggestion_choice(state$entries[[i]]))
}, logical(1))
open_ids <- vapply(state$entries[just_changed], function(e) as.integer(e$id), integer(1))
tag_order <- if (identical(kind, "docs")) {
  read_config_yaml("config/roxygen-style.yml")$tag_order
}

changed_files <- character(0)
for (i in seq_along(state$entries)) {
  e <- state$entries[[i]]
  choice <- suggestion_choice(e)
  if (identical(choice, "none")) {
    next
  }
  ticked <- identical(choice, "ticked")
  result <- if (identical(kind, "tests")) {
    apply_test_choice(e, ticked, base_ref)
  } else {
    apply_roxygen_choice(e, ticked, base_ref, tag_order)
  }

  if (!result$ok) {
    message(sprintf("E%d: can't apply the choice — %s. Its box is set back.", as.integer(e$id), result$note))
    state$entries[[i]]$choice <- !ticked
    state$entries[[i]]$status_note <- result$note
    next
  }
  if (result$changed) {
    done <- "reverted"
    if (ticked) {
      done <- "applied"
    }
    what <- sprintf("`%s`", e$field)
    if (identical(kind, "tests")) {
      what <- sprintf("\"%s\"", e$description)
    }
    message(sprintf("E%d: %s %s in %s.", as.integer(e$id), done, what, e$file))
    changed_files <- c(changed_files, e$file)
  }
  # A not-applied roxygen suggestion the user ticked is now an applied
  # change (unticking it later declines it).
  if (ticked && identical(e$kind, "dropped")) {
    state$entries[[i]]$kind <- "applied"
  }
}

writeLines(unique(changed_files), "updated_files.txt")

# The description: everything before the report (the bot PR's intro) and
# the hidden markers after it stay; the report is rebuilt from the state.
if (length(changed_files) > 0 || !identical(state, before)) {
  report <- if (identical(kind, "tests")) {
    format_test_report(state, NULL, state$legacy, open = open_ids)
  } else {
    format_roxygen_report(state, NULL, state$legacy, open = open_ids)
  }
  lines <- strsplit(body, "\r?\n")[[1]]
  report_start <- which(startsWith(lines, "**Summary:**"))[1]
  intro <- if (!is.na(report_start) && report_start > 1) {
    lines[seq_len(report_start - 1)]
  } else {
    character(0)
  }
  markers <- lines[grepl("^<!-- bot-suggest: (reviewed up to|retry) ", lines)]
  # The bot's "Latest review" line stays under the summary.
  report <- strsplit(report, "\n", fixed = TRUE)[[1]]
  latest <- lines[startsWith(lines, "**Latest review**")]
  if (length(latest) > 0) {
    report <- append(report, c("", latest[1]), after = 1)
  }
  writeLines(c(intro, report, "", markers), "new_body.md")
}
