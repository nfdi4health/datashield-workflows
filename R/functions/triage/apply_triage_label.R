# Sets the GitHub label of a triage's category (config/issue-triage.yml)
# on the issue. The label of the last triage goes when the verdict changes;
# labels people added stay. This is the only change triage makes to an
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
  previous <- issue$previous_category
  old <- if (is.null(previous)) NULL else settings$categories[[previous]]$github_label
  if (!is.null(old) && !identical(old, label) && old %in% issue$labels) {
    remove_issue_label(number, old)
  }
  if (!label %in% issue$labels) {
    post_github_json(sprintf("/repos/%s/issues/%s/labels", repo, number), list(labels = list(label)), "triage label")
  }
  invisible(NULL)
}

# Sets the warning label if Claude found an attempt to steer it
# (settings$suspicious_label). Later verdicts don't touch it: only a person
# removes it, having looked. A signal, not a barrier: a clever attempt may
# go unnoticed. A failure is only logged, as above.
apply_suspicious_label <- function(number, answer, issue, settings) {
  label <- settings$suspicious_label
  if (!isTRUE(answer$manipulation_attempt) || label %in% issue$labels) {
    return(invisible(NULL))
  }
  post_github_json(sprintf("/repos/%s/issues/%s/labels", repo, number), list(labels = list(label)), "warning label")
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
