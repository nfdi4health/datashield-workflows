# A transformation file (write_transformation_file()) as list(entries,
# classifications), each keyed by id; both empty when the file doesn't
# exist or is empty.
read_transformation_file <- function(path) {
  if (!nzchar(path) || !file.exists(path)) {
    return(list(entries = list(), classifications = list()))
  }
  data <- yaml::read_yaml(path) %||% list()
  by_id <- function(items) stats::setNames(items, vapply(items, function(e) e$id, character(1)))
  list(entries = by_id(data$entries %||% list()), classifications = by_id(data$classifications %||% list()))
}
