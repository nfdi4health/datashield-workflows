# The open issues in the collection repository (`repo`) that report a
# missing DataSHIELD function: those whose title starts with `title_prefix`
# (the fixed part of texts$issue$title), pull requests left out. Read-only;
# works for a public repository with any token. Up to `max_issues`, newest
# first. Returns a data frame (number, title, url); empty if none or the
# repository can't be read.
fetch_gap_issues <- function(repo, title_prefix, max_issues) {
  found <- list()
  page <- 1
  while (length(found) < max_issues) {
    batch <- get_github_json(sprintf("/repos/%s/issues?state=open&per_page=100&page=%d", repo, page))
    if (length(batch) == 0) {
      break
    }
    for (i in batch) {
      if (is.null(i$pull_request) && startsWith(i$title, title_prefix)) {
        found[[length(found) + 1]] <- data.frame(number = i$number, title = i$title, url = i$html_url)
      }
    }
    if (length(batch) < 100) {
      break
    }
    page <- page + 1
  }
  if (length(found) == 0) {
    return(data.frame(number = integer(0), title = character(0), url = character(0)))
  }
  head(do.call(rbind, found), max_issues)
}
