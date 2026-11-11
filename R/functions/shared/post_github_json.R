# Shared low-level GitHub API POST mechanics — used for PR comments and
# issue creation alike. Failure is
# reported via message(), never stop(): one failed post shouldn't abort
# the whole run over every other file/function still being processed.
post_github_json <- function(path, body, context, token = gh_token) {
  req <- request(sprintf("https://api.github.com%s", path)) |>
    req_headers("Authorization" = paste("Bearer", token), "Accept" = "application/vnd.github+json") |>
    req_body_json(body)

  tryCatch(req_perform(req), error = function(e) {
    message(sprintf("Failed to post to GitHub (%s): %s", context, conditionMessage(e)))
  })
}
