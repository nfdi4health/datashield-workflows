# Shared low-level GitHub API GET mechanics — counterpart of
# post_github_json(). Returns the parsed body, or NULL on any HTTP error so
# the caller can skip that item instead of aborting the run. Without a
# token (local runs) the request goes out unauthenticated — enough for
# public repositories.
get_github_json <- function(path) {
  req <- request(sprintf("https://api.github.com%s", path)) |>
    req_headers("Accept" = "application/vnd.github+json") |>
    req_error(is_error = function(resp) FALSE)
  if (nzchar(gh_token)) {
    req <- req_headers(req, "Authorization" = paste("Bearer", gh_token))
  }
  resp <- req_perform(req)

  if (resp_status(resp) >= 400) {
    return(NULL)
  }
  resp_body_json(resp)
}
