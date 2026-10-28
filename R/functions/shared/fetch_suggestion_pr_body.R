# The description of the open bot PR from `branch` (the bot branch of the
# reviewed branch, e.g. bot-suggest/docs/dev), or NULL if none is
# open. Only an open PR counts: a merged or closed one has nothing to
# build on.
fetch_suggestion_pr_body <- function(branch) {
  owner <- sub("/.*$", "", repo)
  prs <- tryCatch(
    get_github_json(sprintf("/repos/%s/pulls?state=open&head=%s:%s", repo, owner, utils::URLencode(branch, reserved = TRUE))),
    error = function(e) {
      message("Could not look up the open bot PR: ", conditionMessage(e))
      list()
    }
  )
  if (length(prs) == 0) {
    return(NULL)
  }
  if (is.null(prs[[1]]$body)) {
    ""
  } else {
    prs[[1]]$body
  }
}
