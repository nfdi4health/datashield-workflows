# The sampling state per field and publication month (months.csv in the
# data folder): the search's fingerprint (`query`), how many papers PubMed
# lists (`total`), the target the sample was drawn for, the key of the last
# paper in the sample (`threshold`: a paper counts for the field when its
# key is at most this), how many of the sample are read (`sample_read`) and
# when the month was last searched (`checked`).
read_months_state <- function(dir) {
  path <- file.path(dir, "months.csv")
  empty <- data.frame(field = character(0), month = character(0), query = character(0), total = integer(0),
    target = integer(0), threshold = character(0), sample_read = integer(0), checked = character(0))
  if (!file.exists(path)) return(empty)
  state <- utils::read.csv(path, colClasses = c("character", "character", "character", "integer", "integer",
    "character", "integer", "character"), na.strings = "")
  state$threshold[is.na(state$threshold)] <- ""
  state
}
