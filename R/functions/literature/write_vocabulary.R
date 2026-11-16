# Writes the vocabulary (read_vocabulary()) with its entries sorted, so a
# night's changes show as small diffs on the data branch.
write_vocabulary <- function(vocab, dir) {
  sort_list <- function(x) if (length(x) == 0) list() else x[order(names(x))]
  out <- list(
    methods = lapply(sort_list(vocab$methods), function(m) {
      if (!is.null(m$variants)) m$variants <- sort_list(m$variants)
      m
    }),
    names = sort_list(vocab$names),
    variant_names = lapply(sort_list(vocab$variant_names), sort_list)
  )
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(out, file.path(dir, "vocabulary.yml"))
}
