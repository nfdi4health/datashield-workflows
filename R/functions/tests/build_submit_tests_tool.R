# Builds the Claude tool-call JSON schema for submit_tests. Same
# deterministic-assembly principle as roxygen-suggest's
# build_submit_review_tool(): Claude returns discrete fields (never
# assembled test_that() syntax), the R script does the actual stitching.
# The cap on new tests (tests.max_new_tests in config/suggestion-policy.yml) is maxItems
# here and enforced in R too (ask_claude_for_tests()), since strict tool
# use doesn't send maxItems — not just prompt wording.
#
# Each new test carries a `reason` from a fixed list; filter_generated_tests()
# keeps only the accepted reasons. "other" is the honest way out for a test
# that adds no real value. Decisions on existing tests (update / delete /
# report) are checked by review_existing_tests() — see
# dev-notes/suggestion-thresholds.md.
#
# **The same for every function of a run** (dev-notes/claude-costs.md): the
# tool definition comes first in the request, before the prompt part that
# is cached (split_cached_prompt()), so any per-function difference here
# would invalidate the cache for every call. Hence no per-function enums:
# the function's test file names (`test_file`) and the ids of earlier
# findings (`repeats_earlier`, `earlier_findings`) are plain strings, and R
# checks every value Claude returns — an unknown file or id is ignored
# (sort_test_decisions(), merge_test_findings(),
# handle_failed_new_test()). What may vary is per run only:
# - `dslite_datasets`: config/dslite-canned-datasets.yml$datasets when the
#   run may create a DSLite setup, else NULL. The enum covers all of them;
#   the prompt offers them only for a function that gets a fresh setup, and
#   the entry script uses the choice only then;
# - `categories` (detect_test_scheme(), categorised repositories only): a
#   category per new test.
# A new test file can get top-level setup and teardown code
# (new_test_file_content()).
build_submit_tests_tool <- function(dslite_datasets, max_new_tests, categories = NULL) {
  repeats_earlier <- list(type = "string",
                          description = "The id of an earlier finding listed with the function (e.g. \"E3\") that this one repeats, also in other words; empty string if it is new or there are no earlier findings.")
  code_fields <- list(
    setup_code = list(type = "string", description = "Raw runnable R code needed only for this specific test (e.g. extra assigns), beyond the shared connection/setup. Empty string if nothing extra is needed."),
    assertions_code = list(type = "string", description = "Raw runnable R code containing the actual expect_*() assertion(s) for this test. No comment markers, no test_that() wrapper — the script adds that.")
  )

  test_item_schema <- list(
    type = "object",
    properties = c(list(
      description = list(type = "string", description = "The test_that() description — says exactly what is asserted."),
      reason = list(
        type = "string",
        enum = as.list(suggestion_reasons("tests")),
        description = paste("Why this test adds value.", format_reason_meanings("tests"))   # config/suggestion-policy.yml
      )
    ), code_fields, list(repeats_earlier = repeats_earlier)),
    required = list("description", "reason", "setup_code", "assertions_code", "repeats_earlier")
  )
  if (length(categories) > 0) {
    test_item_schema$properties$category <- list(
      type = "string", enum = as.list(unname(categories)),
      description = "The test file category this test belongs to (see the categories in the prompt); the script writes the test into test-<category>-<R file>.R, <R file> being the function's file name without .R."
    )
    test_item_schema$required <- c(test_item_schema$required, list("category"))
  }

  existing_item_schema <- list(
    type = "object",
    properties = c(list(
      test_file = list(type = "string", description = "The file name of the test, exactly as listed with the function's test files (e.g. test-ds.mean.R)."),
      description = list(type = "string", description = "The existing test_that() description, copied exactly."),
      action = list(
        type = "string",
        enum = list("update", "delete", "report"),
        description = "update: replace the test's body (keeps its description). delete: remove the test. report: leave it unchanged and report it."
      ),
      reason = list(
        type = "string",
        enum = list("contract_changed", "duplicate", "behavior_removed", "trivial", "possible_code_bug"),
        description = paste(
          "contract_changed (with update): the function's behavior was changed on purpose and the test still",
          "expects the old behavior. duplicate / behavior_removed / trivial (with delete): another test checks",
          "the same thing / the tested behavior no longer exists / asserts nothing meaningful.",
          "possible_code_bug (with report): the test describes sensible behavior the code no longer delivers."
        )
      ),
      explanation = list(type = "string", description = "One or two sentences why, citing the evidence (history, diff, failure output)."),
      confidence = list(type = "string", enum = list("high", "medium", "low"),
                        description = "How sure you are of this decision; for a report, how sure you are that the code, not the test, is wrong.")
    ), code_fields, list(repeats_earlier = repeats_earlier)),
    required = list("test_file", "description", "action", "reason", "explanation", "confidence", "setup_code", "assertions_code", "repeats_earlier")
  )

  dslite_dataset_schema <- list(
    type = "string",
    description = "Only when the function's part offers a fresh DSLite setup: the chosen canned dataset's name from the options given. Empty string otherwise (server-side functions, functions that don't use DataSHIELD connections, or when reusing an existing setup)."
  )
  if (!is.null(dslite_datasets)) {
    dslite_dataset_schema$enum <- as.list(c("", vapply(dslite_datasets, function(d) d$name, character(1), USE.NAMES = FALSE)))
  }

  input_schema <- list(
    type = "object",
    properties = list(
      needs_tests = list(type = "boolean", description = "Whether new tests would add real value. False if the existing tests already cover the function's behavior well."),
      dslite_dataset = dslite_dataset_schema,
      file_setup_code = list(type = "string", description = "Only if the package's test files connect or set up at their top level, outside test_that() (e.g. a connect helper at the start of each file): that top-level code for the start of a test file that doesn't exist yet. Empty string otherwise."),
      file_teardown_code = list(type = "string", description = "The matching top-level clean-up for the end of such a new test file (e.g. the disconnect helper). Empty string otherwise."),
      tests = list(
        type = "array",
        description = sprintf("Up to %d new test_that() blocks. Never duplicates an existing test.", max_new_tests),
        items = test_item_schema,
        maxItems = max_new_tests
      ),
      existing_tests = list(
        type = "array",
        description = "Decisions on existing tests that need action. Leave out tests that are fine — an empty array is the normal case.",
        items = existing_item_schema
      ),
      earlier_findings = list(
        type = "array",
        description = "Your judgement of each earlier finding listed with the function; an empty array if there are none.",
        items = list(
          type = "object",
          properties = list(
            id = list(type = "string", description = "The earlier finding's id as listed, e.g. \"E3\"."),
            status = list(type = "string", enum = list("still_valid", "superseded", "resolved"),
                          description = "still_valid: still correct and open. superseded: no longer correct, e.g. the code changed or it was wrong. resolved: the code or tests now do what it asked for."),
            note = list(type = "string", description = "One sentence why, for superseded or resolved; empty string for still_valid.")
          ),
          required = list("id", "status", "note")
        )
      )
    ),
    required = list("needs_tests", "dslite_dataset", "file_setup_code", "file_teardown_code", "tests", "existing_tests", "earlier_findings")
  )

  list(
    description = "Submit new and changed testthat tests as individual structured fields, never as assembled test_that() syntax.",
    input_schema = input_schema
  )
}
