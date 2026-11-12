# For a step that runs only on some studies (the plan's `studies` list in
# that step): every DataSHIELD call that takes a `datasources` argument
# (`reference$functions`, client_function_reference()) must pass one, and
# not the whole connections object (`connections`, e.g. conns). Which
# servers a subset like conns[c("a", "b")] names is left to the test run;
# this only catches calls that would run on every study. Returns the
# problems found, worded by `texts$checks`.
check_step_datasources <- function(code, studies, connections, reference, texts) {
  if (length(studies) == 0) {
    return(character(0))
  }
  problems <- character(0)
  walk_code(code, function(x, arg) {
    if (!is.call(x)) {
      return()
    }
    head <- x[[1]]
    name <- if (is.name(head)) {
      as.character(head)
    } else if (is.call(head) && as.character(head[[1]]) %in% c("::", ":::")) {
      as.character(head[[3]])
    } else {
      NA_character_
    }
    if (is.na(name) || !grepl("^(ds|datashield)\\.", name)) {
      return()
    }
    fn <- reference$functions[[name]]
    if (is.null(fn) || !"datasources" %in% fn$args) {
      return()
    }
    given <- if ("datasources" %in% names(x)) x[["datasources"]]
    if (is.null(given) || (is.name(given) && identical(as.character(given), connections))) {
      problems <<- c(problems, fill_template(texts$checks$step_datasources, list(
        STUDIES = paste(studies, collapse = ", "), CONNECTIONS = connections,
        QUOTED = paste(sprintf("\"%s\"", studies), collapse = ", "), FUNCTION = name
      )))
    }
  })
  unique(problems)
}
