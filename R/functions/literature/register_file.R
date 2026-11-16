# Where the literature watch keeps the papers of one publication month in
# its data folder: papers/YYYY/YYYY-MM.jsonl, one JSON line per paper.
register_file <- function(dir, month) {
  file.path(dir, "papers", substr(month, 1, 4), paste0(month, ".jsonl"))
}
