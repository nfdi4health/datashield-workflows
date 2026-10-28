# A failure R can classify without Claude, from the error message alone:
# the generated test doesn't parse, or calls a function that exists
# nowhere (bad_test); a package isn't installed (env_misconfiguration).
# Returns a classification like Claude's (explanation, category,
# confidence) or NULL when the message needs a judgment call.
obvious_failure_classification <- function(message) {
  msg <- paste(message, collapse = " ")
  known <- function(category, why) list(explanation = paste("Recognised without Claude:", why), category = category, confidence = "high")
  if (grepl("unexpected (symbol|string constant|numeric constant|input|'[^']*'|end of input)|parse error", msg, ignore.case = TRUE)) {
    return(known("bad_test", "the generated test code doesn't parse."))
  }
  fn <- regmatches(msg, regexec("could not find function \"([^\"]+)\"", msg))[[1]]
  if (length(fn) == 2) {
    return(known("bad_test", sprintf("the test calls `%s()`, which doesn't exist.", fn[2])))
  }
  pkg <- regmatches(msg, regexec("there is no package called .([A-Za-z0-9.]+).", msg))[[1]]
  if (length(pkg) == 2) {
    return(known("env_misconfiguration", sprintf("the package `%s` isn't installed in the test environment.", pkg[2])))
  }
  NULL
}
