# The R files of the repository's R/ folder on the default branch, by file
# name, for the shortlist to pick the functions an issue is about (one
# function per file is the packages' convention). One call; empty when
# there is no R/ folder (not an R package), and the triage goes on without
# documentation.
list_r_files <- function() {
  entries <- get_github_json(sprintf("/repos/%s/contents/R", repo))
  if (is.null(entries) || !is.null(entries$type)) {
    return(character(0))
  }
  files <- vapply(Filter(function(x) identical(x$type, "file"), entries), function(x) x$name %||% "", character(1))
  sort(files[grepl("\\.[Rr]$", files)])
}
