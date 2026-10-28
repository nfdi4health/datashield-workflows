# Carries a person's decisions over into this run's entries (`new`, both
# lists keyed by id, previous from the transformation file): an
# "approved" or "skip" status is kept, and so is a proposed name a person
# changed on an approved entry (the rules' current proposal goes into the
# note). "applied" entries stay as history even though their argument is
# gone. Everything else is this run's result.
merge_naming_entries <- function(new, previous) {
  for (id in intersect(names(new), names(previous))) {
    prev <- previous[[id]]
    if (!prev$status %in% c("approved", "skip")) {
      next
    }
    new[[id]]$status <- prev$status
    if (prev$status == "approved" && !identical(prev$proposed, new[[id]]$proposed) && nzchar(prev$proposed %||% "")) {
      if (nzchar(new[[id]]$proposed %||% "")) {
        new[[id]]$note <- sprintf("rules now propose `%s`; kept the approved `%s`", new[[id]]$proposed, prev$proposed)
      }
      new[[id]]$proposed <- prev$proposed
    }
  }
  applied <- Filter(function(e) identical(e$status, "applied"), previous[setdiff(names(previous), names(new))])
  c(new, applied)
}
