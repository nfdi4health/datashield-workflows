# How many columns a diagram has: the longest path from `start` along
# `arrows` (a list of c(from, to) node IDs), counting `start` as 1. Loops
# can't make it grow forever — no path counts beyond 20.
diagram_depth <- function(arrows, start = "ev") {
  depth <- stats::setNames(1, start)
  repeat {
    changed <- FALSE
    for (a in arrows) {
      if (!is.na(depth[a[1]]) && depth[a[1]] < 20 && (is.na(depth[a[2]]) || depth[a[2]] < depth[a[1]] + 1)) {
        depth[a[2]] <- depth[a[1]] + 1
        changed <- TRUE
      }
    }
    if (!changed) {
      break
    }
  }
  max(depth)
}
