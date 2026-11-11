# post_issue_once(): new issues are opened with the App's token when the
# workflow has one, so that triage sees them; GH_TOKEN otherwise or as a
# fallback.

local_issue_api <- function(fail_with = character(0), env = parent.frame()) {
  calls <- new.env()
  calls$tokens <- character(0)
  assign("repo", "me/pkg", envir = globalenv())
  assign("gh_token", "actions-token", envir = globalenv())
  withr::defer({
    for (name in c("repo", "gh_token")) if (exists(name, envir = globalenv())) rm(list = name, envir = globalenv())
  }, envir = env)
  local_global_mock(
    get_github_json = function(path) list(),
    post_github_json = function(path, body, context, token = gh_token) {
      calls$tokens <- c(calls$tokens, token)
      if (token %in% fail_with) return(NULL)
      structure(list(), class = "httr2_response")
    },
    env = env
  )
  calls
}

test_that("a new issue is opened with ISSUE_TOKEN when there is one", {
  withr::local_envvar(ISSUE_TOKEN = "app-token")
  calls <- local_issue_api()
  post_issue_once("A finding", "Body", "test")
  expect_equal(calls$tokens, "app-token")
})

test_that("without ISSUE_TOKEN, or when it fails, GH_TOKEN opens the issue", {
  withr::local_envvar(ISSUE_TOKEN = "")
  calls <- local_issue_api()
  post_issue_once("A finding", "Body", "test")
  expect_equal(calls$tokens, "actions-token")

  withr::local_envvar(ISSUE_TOKEN = "expired-token")
  calls <- local_issue_api(fail_with = "expired-token")
  post_issue_once("A finding", "Body", "test")
  expect_equal(calls$tokens, c("expired-token", "actions-token"))
})
