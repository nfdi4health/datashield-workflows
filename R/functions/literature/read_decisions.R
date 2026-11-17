# The decisions on earlier candidates (decisions.json in the data folder,
# written by the hub's literature-candidates workflow when a candidate
# pull request is merged): per key the decision ("issue", "not-now" or
# "dont-suggest"), its date, the papers at the time, the pull request and
# the issue opened. An empty list when there is none yet.
read_decisions <- function(dir) {
  path <- file.path(dir, "decisions.json")
  if (!file.exists(path)) return(list())
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}
