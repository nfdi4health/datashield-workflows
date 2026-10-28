# The order of the workflows in the table — the
# way they come into play rather than alphabetical: situation by situation
# (workflow_situations(): PR into dev, PR closed, PR into main, …), each
# workflow followed by the workflows it starts (`chains`), then anything
# left (manual-only or called-only workflows). Returns the workflows,
# reordered.
workflow_order <- function(workflows, chains) {
  files <- vapply(workflows, function(wf) wf$file, character(1))
  ordered <- character(0)
  add <- function(f) {
    if (f %in% ordered) {
      return(invisible())
    }
    ordered <<- c(ordered, f)
    for (ch in Filter(function(ch) identical(ch$from, f), chains)) {
      add(ch$to)
    }
  }
  for (s in workflow_situations(workflows, chains)) {
    for (f in names(s$members)) {
    add(f)
  }
  }
  for (f in files) {
    add(f)
  }
  workflows[match(ordered, files)]
}
