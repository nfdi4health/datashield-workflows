# The three decision boxes of one candidate in the candidate pull request,
# after its hidden marker (read back by the hub's literature-candidates
# workflow: exactly one ticked per candidate).
candidate_boxes <- function(key) {
  c(sprintf("<!-- candidate: %s -->", key), "- [ ] Open an issue", "- [ ] Not now", "- [ ] Don't suggest again")
}
