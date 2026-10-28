# Parses one GitHub Actions workflow file into list(file, name, triggers,
# jobs). `triggers` is always a named list event -> settings (NULL when
# the event has none), whether the file writes `on: push`,
# `on: [push, pull_request]` or the full mapping. The yaml package reads
# a bare `on:` key as the boolean TRUE (YAML 1.1), so both spellings are
# looked up. `name` falls back to the file name, as GitHub does.
parse_workflow_yaml <- function(text, file) {
  spec <- yaml::yaml.load(text)
  on <- spec[["on"]] %||% spec[["TRUE"]]

  if (is.character(on)) {
    triggers <- stats::setNames(vector("list", length(on)), on)
  } else if (is.list(on)) {
    triggers <- on
  } else {
    triggers <- list()
  }

  list(
    file = file,
    name = spec$name %||% file,
    triggers = triggers,
    jobs = spec$jobs %||% list()
  )
}
