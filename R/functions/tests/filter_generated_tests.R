# Threshold for generated tests (see dev-notes/suggestion-thresholds.md):
# keeps a test only if Claude's reason is in accept_reasons, its
# description doesn't clash with an existing test (results are matched by
# description), and its assertions aren't already in the existing test
# file verbatim (ignoring whitespace), and it replaces no function of base
# R (mocked_base_functions(); `own`: the package's own names), which R CMD
# check would fail. Everything dropped is logged; the tests dropped for a
# base function come back as the attribute "base_mocks" (list of
# list(description, functions)), for the report's "Hard to test".
filter_generated_tests <- function(tests, existing_content, accept_reasons, function_name, existing_descriptions = character(0),
                                   own = character(0)) {
  squash <- function(x) gsub("\\s+", "", x)
  existing <- squash(existing_content)
  base_mocks <- list()

  kept <- Filter(function(t) {
    if (!isTRUE(t$reason %in% accept_reasons)) {
      message(sprintf("%s: dropping test '%s' — reason '%s' is not accepted.", function_name, t$description, t$reason))
      return(FALSE)
    }
    if (t$description %in% existing_descriptions) {
      message(sprintf("%s: dropping test '%s' — an existing test has the same name.", function_name, t$description))
      return(FALSE)
    }
    assertions <- squash(t$assertions_code)
    if (nzchar(existing) && nzchar(assertions) && grepl(assertions, existing, fixed = TRUE)) {
      message(sprintf("%s: dropping test '%s' — its assertions already exist.", function_name, t$description))
      return(FALSE)
    }
    mocked <- mocked_base_functions(paste(t$setup_code %||% "", t$assertions_code %||% "", sep = "\n"), own)
    if (length(mocked) > 0) {
      message(sprintf("%s: dropping test '%s' — it replaces %s, which R CMD check fails.", function_name, t$description,
        paste(mocked, collapse = ", ")))
      base_mocks[[length(base_mocks) + 1]] <<- list(description = t$description, functions = mocked)
      return(FALSE)
    }
    TRUE
  }, tests)
  attr(kept, "base_mocks") <- base_mocks
  kept
}
