# A GitHub list endpoint read page by page, 100 items at a time, as one
# list — counterpart of get_github_json() for lists longer than one page
# (`gh api --paginate` in the shell scripts). Stops at the first page with
# fewer than 100 items, or after `max_pages`, which bounds the calls for a
# very long list. A page that can't be read ends the list there; NULL only
# if the first one fails, as get_github_json() does.
get_github_json_pages <- function(path, max_pages = 10) {
  separator <- if (grepl("?", path, fixed = TRUE)) "&" else "?"
  items <- list()
  for (page in seq_len(max_pages)) {
    batch <- get_github_json(sprintf("%s%sper_page=100&page=%d", path, separator, page))
    if (is.null(batch)) {
      if (page == 1) {
        return(NULL)
      }
      break
    }
    items <- c(items, batch)
    if (length(batch) < 100) {
      break
    }
  }
  items
}
