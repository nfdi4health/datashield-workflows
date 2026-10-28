# Deterministic assembly: the ONLY place test_that() blocks are built, from
# Claude's structured fields. Same principle as roxygen-suggest's
# build_roxygen_block() — Claude never produces final syntax directly.
# Returns a NAMED character vector of complete test_that() block strings
# (one per item in `tests`), named by the test's original (unescaped)
# description — the same string testthat itself will report back after
# running, so callers can match pass/fail results back to specific blocks
# without re-parsing generated source. NOT yet run, NOT yet written to disk.
assemble_test_block <- function(tests, function_name) {
  clean <- function(text, field_name) {
    strip_artifact_lines(text, "^\\s*```", "markdown code fences", field_name, function_name)
  }

  blocks <- vapply(tests, function(t) {
    description <- clean(t$description, "description")
    setup_code  <- clean(t$setup_code, "setup_code")
    assertions  <- clean(t$assertions_code, "assertions_code")

    if (!nzchar(trimws(description))) {
      stop(sprintf("%s: a test's 'description' field was empty after sanitization.", function_name))
    }
    if (!nzchar(trimws(assertions))) {
      stop(sprintf("%s: a test's 'assertions_code' field was empty after sanitization.", function_name))
    }

    body_lines <- strsplit(assertions, "\n")[[1]]
    if (nzchar(trimws(setup_code))) {
      body_lines <- c(strsplit(setup_code, "\n")[[1]], body_lines)
    }
    body <- paste(paste0("  ", body_lines), collapse = "\n")

    sprintf('test_that("%s", {\n%s\n})', gsub('"', '\\"', description, fixed = TRUE), body)
  }, character(1))

  names(blocks) <- vapply(tests, function(t) t$description, character(1))
  blocks
}
