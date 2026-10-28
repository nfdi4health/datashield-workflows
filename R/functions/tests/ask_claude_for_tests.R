# Sends the test-review request to Claude and returns the submit_tests
# tool call's input — individual structured fields only, never assembled
# test_that() syntax. Besides the function and its test files, Claude gets
# the test setup/helper files and the files they source verbatim (to use
# the package's own objects, connection helpers and helpers), example test
# files of other functions when this one has none yet, how the repository
# names its test files, the structure of the test data
# (summarize_test_data()), the existing tests' current results and the
# history evidence, to judge failing tests (outdated vs. possible bug),
# and this bot's open earlier findings (`context$earlier`) to judge and not
# repeat.
# `context` bundles the per-run and per-function inputs; see
# R/suggest_tests.R. When the run reviews several files
# (`context$cache_prompt`), the prompt's shared part (instructions and the
# package's test material) is sent with a cache marker
# (split_cached_prompt()); the tool definition is the same for every
# function of the run, so from the second function on that part is read
# from the prompt cache. `context$dataset_choices` are the run's DSLite
# datasets for the tool schema; `context$dslite_datasets` the ones offered
# to this function (NULL unless it gets a fresh setup).
ask_claude_for_tests <- function(claude, parsed, context) {
  prompt <- fill_template(claude$prompt, list(
    ROLE_GUIDANCE         = context$role_text,
    TEST_FILE_SCHEME      = context$scheme_text,
    EXISTING_TEST_FILES   = format_test_files(context$test_files, "(none yet)"),
    EXAMPLE_TEST_FILES    = format_test_files(context$examples, "(not needed: the function has tests)", max_chars = 8000),
    TEST_SUPPORT_FILES    = format_test_support_files(context$support_files),
    TEST_DATA             = context$test_data,
    EXISTING_TEST_RESULTS = context$test_results,
    HISTORY_EVIDENCE      = context$evidence,
    FUNCTION_SOURCE       = fn_source(parsed),
    FUNCTION_NAME         = parsed$fn_name,
    MAX_NEW_TESTS         = as.character(context$max_new_tests),
    EARLIER_FINDINGS      = format_earlier_test_findings(context$earlier)
  ))

  tool <- build_submit_tests_tool(context$dataset_choices, context$max_new_tests, categories = context$categories)
  # Cached only when the run reviews more than one file: the cache lives
  # minutes, runs are hours or days apart, and a single call would pay the
  # cache write (1.25x input) without ever reading it.
  sent <- if (isTRUE(context$cache_prompt)) {
    split_cached_prompt(prompt)
  } else {
    sub("<!-- per function -->\n", "", prompt, fixed = TRUE)
  }
  answer <- call_claude_tool(claude, tool, sent)
  # The schema's maxItems isn't sent in strict mode (strict_tool_schema()):
  # the cap holds here either way.
  if (length(answer$tests) > context$max_new_tests) {
    answer$tests <- answer$tests[seq_len(context$max_new_tests)]
  }
  answer
}
