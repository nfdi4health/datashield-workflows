# Sets the GitHub label of a triage's category (config/issue-triage.yml)
# on the issue. An earlier "needs more information" label goes when the
# answer is another category. This is the only change triage makes to an
# issue besides its comment; it never closes one.
#
# The category comes from Claude reading untrusted text, so the label must
# never be able to act as an approval: the approval label is refused, in
# any case, whatever the config says. A label that can't be set is only
# logged, because the comment that matters is already posted, and retrying
# would mean a second triage.
apply_triage_label <- function(number, category, issue, settings, approval_label) {
  label <- settings$categories[[category]]$github_label
  if (is.null(label) || !nzchar(label)) {
    return(invisible(NULL))
  }
  if (identical(tolower(label), tolower(approval_label))) {
    stop(sprintf("Triage must not set the approval label %s.", approval_label), call. = FALSE)
  }
  asked <- settings$categories[["needs-info"]]$github_label
  if (!identical(category, "needs-info") && !is.null(asked) && asked %in% issue$labels) {
    remove_issue_label(number, asked)
  }
  if (!label %in% issue$labels) {
    post_github_json(sprintf("/repos/%s/issues/%s/labels", repo, number), list(labels = list(label)), "triage label")
  }
  invisible(NULL)
}

# Removes a label from an issue; a failure is only logged, as above.
remove_issue_label <- function(number, label) {
  path <- sprintf("/repos/%s/issues/%s/labels/%s", repo, number, utils::URLencode(label, reserved = TRUE))
  req <- request(sprintf("https://api.github.com%s", path)) |>
    req_method("DELETE") |>
    req_headers("Authorization" = paste("Bearer", gh_token), "Accept" = "application/vnd.github+json")
  tryCatch(req_perform(req), error = function(e) {
    message(sprintf("Could not remove the label %s: %s", label, conditionMessage(e)))
  })
}
