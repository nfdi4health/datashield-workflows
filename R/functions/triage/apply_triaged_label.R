# Marks an issue as triaged (settings$triaged_label), so that a maintainer
# can filter for "triaged, waiting for my decision". It stays, through later
# triages too. Never the approval label, whatever the config says; a label
# that can't be set is only logged, as in apply_triage_label().
apply_triaged_label <- function(number, issue, settings, approval_label) {
  label <- settings$triaged_label %||% ""
  if (!nzchar(label) || label %in% issue$labels) {
    return(invisible(NULL))
  }
  if (identical(tolower(label), tolower(approval_label))) {
    stop(sprintf("Triage must not set the approval label %s.", approval_label), call. = FALSE)
  }
  post_github_json(sprintf("/repos/%s/issues/%s/labels", repo, number), list(labels = list(label)), "triaged label")
  invisible(NULL)
}
