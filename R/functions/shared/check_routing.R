# Checks one entry of `routing` in config/suggestion-policy.yml (e.g.
# routing$tests$report) and returns it: `on_pr` may be comment, issue or
# log; `without_pr` issue or log (there is no PR to comment on). `allowed`
# narrows the destinations (authors: no issue). Stops the run on anything
# else, so a typo fails loudly instead of losing findings.
check_routing <- function(entry, name, allowed = c("comment", "issue", "log")) {
  ok <- list(on_pr = allowed, without_pr = setdiff(allowed, "comment"))
  for (situation in intersect(names(entry), names(ok))) {
    if (!isTRUE(entry[[situation]] %in% ok[[situation]])) {
      stop(sprintf("routing %s %s is '%s' in config/suggestion-policy.yml — use one of: %s.",
                   name, situation, paste(entry[[situation]], collapse = ","), paste(ok[[situation]], collapse = ", ")),
           call. = FALSE)
    }
  }
  entry
}
