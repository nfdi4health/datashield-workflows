# Decides per plan step what to do, from the scripts written earlier
# (`existing`, from find_bot_step_files()):
#   new       — no script yet;
#   changed   — scripts untouched, but the plan entry changed: rewrite;
#   unchanged — nothing to do;
#   edited    — the analyst changed a script: never overwritten, only a
#               note if the plan entry changed too.
# Steps with scripts that are no longer in the plan are "removed" (note
# only). Returns list(steps, to_write): `steps` is keyed by step id, each
# with title, status, files, notes, error (text for the report, from
# `texts$step`, filled with `names`: MAIN etc., see the entry script) and
# hash.
classify_plan_steps <- function(plan, existing, texts, names) {
  steps <- list()
  for (s in plan$steps) {
    own <- existing[existing$step == s$id, ]
    hash <- step_plan_hash(plan, s)
    status <- if (nrow(own) == 0) {
      "new"
    }
      else if (any(own$edited)) {
        "edited"
      }
      else if (all(own$plan_hash == hash)) {
        "unchanged"
      }
      else {
        "changed"
      }
    error <- if (status == "edited" && !all(own$plan_hash == hash)) {
      texts$step$edited_plan_changed
    }
    steps[[s$id]] <- list(title = s$title, status = status, files = own$path, notes = list(), error = error, hash = hash)
  }
  ids <- vapply(plan$steps, function(s) s$id, character(1))
  for (gone in setdiff(unique(existing$step), ids)) {
    steps[[gone]] <- list(title = gone, status = "removed", files = existing$path[existing$step == gone], notes = list(), error = fill_template(texts$step$removed, names))
  }
  to_write <- names(Filter(function(s) s$status %in% c("new", "changed"), steps))
  list(steps = steps, to_write = to_write)
}
