# The reasons of a task with their meanings as one line of text, e.g.
# "missing: the field is absent or a placeholder. inaccurate: …", for a
# tool schema's enum description; with `bullets` TRUE as a Markdown list
# for a prompt. From config/suggestion-policy.yml (suggestion_reasons()).
format_reason_meanings <- function(task, bullets = FALSE) {
  m <- suggestion_reasons(task, meanings = TRUE)
  if (bullets) {
    return(paste(sprintf("- %s: %s;", names(m), m), collapse = "\n"))
  }
  paste(sprintf("%s: %s.", names(m), m), collapse = " ")
}
