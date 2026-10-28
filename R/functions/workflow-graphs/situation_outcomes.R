# A workflow's outcomes (workflow_outcomes()) as they matter in one
# situation — `trigger` is its GitHub event name ("schedule"). A condition
# about the event itself ("only if: scheduled run") decides: on another
# event the outcome is left out ("Scheduled workflows kept enabled" isn't
# shown for a pull request), on its own event the condition goes without
# saying and is dropped; likewise "skipped: <this event>" leaves the
# outcome out. Other conditions stay. Returns the remaining outcomes.
situation_outcomes <- function(outcomes, trigger) {
  here <- event_noun(trigger)
  events <- vapply(c(trigger_order(), "workflow_dispatch"), event_noun, character(1))
  kept <- list()
  for (o in outcomes) {
    parts <- if (nzchar(o$condition)) {
      strsplit(o$condition, ", ", fixed = TRUE)[[1]]
    } else {
      character(0)
    }
    only <- sub("^only if: ", "", parts[startsWith(parts, "only if: ") & sub("^only if: ", "", parts) %in% events])
    skip <- sub("^skipped: ", "", parts[startsWith(parts, "skipped: ") & sub("^skipped: ", "", parts) %in% events])
    if ((length(only) > 0 && !here %in% only) || here %in% skip) {
      next
    }
    o$condition <- paste(setdiff(parts, c(paste("only if:", only), paste("skipped:", skip))), collapse = ", ")
    kept[[length(kept) + 1]] <- o
  }
  kept
}
