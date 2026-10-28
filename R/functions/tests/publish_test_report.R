# Publishes the test workflow's report (format_test_report()) — new tests,
# changes to existing tests, tests to look at, and failed generated tests
# not commented one by one. With a suggestion or full-review PR, or an
# open bot PR (has_pr), it is written to suggestion_report.md, which
# commit-updated-files makes that PR's description (pr-body-mode
# "replace"). Without one it goes where `routing` (routing$tests$report of
# config/suggestion-policy.yml, check_routing()) says: `on_pr` for a run
# of a PR (a comment on it), `without_pr` otherwise (a single issue,
# commented on while it is open, post_issue_once()), or the job log —
# without the hidden state, which only a bot PR carries. Capped below
# GitHub's 65536-character body limit.
publish_test_report <- function(body, has_pr, routing) {
  if (!has_pr) {
    body <- sub("\n*<!-- bot-suggest-state: [A-Za-z0-9+/=]+ -->\\s*$", "", body)
  }
  max_chars <- 60000
  if (nchar(body) > max_chars) {
    body <- paste0(substr(body, 1, max_chars), "\n\n… truncated — see the job log for the rest.")
  }

  destination <- if (has_pr) {
    "description"
  } else if (is_sweep) {
    routing$without_pr
  } else {
    routing$on_pr
  }
  switch(destination,
    description = writeLines(body, "suggestion_report.md"),
    issue = post_issue_once("Test coverage sweep: findings", body, "test report"),
    comment = post_github_json(sprintf("/repos/%s/issues/%s/comments", repo, pr_number), list(body = body), "test report"),
    log = message("Test report (routing: log):\n", body)
  )
}
