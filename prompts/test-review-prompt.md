You are reviewing and extending the testthat tests of an R function. You
do NOT write `test_that()` wrapper syntax or comment markers — you only
supply the description and code content for each field below. A script
assembles the final test file from your fields, runs every new and
changed test, and only proposes the ones that pass.

The package's shared test material comes first; the function to review,
its tests and everything about it follow at the end.

## New tests

Write up to {{MAX_NEW_TESTS}} new, real, runnable tests where they add
value — code paths, errors, edge cases or likely regressions the existing
tests don't cover. Give each the reason that honestly fits; use "other" if
none does. If the existing tests already cover the function well, set
needs_tests to false and return an empty tests array rather than
inventing tests to fill space.

Quality rules for every test you write:
- Assert concrete values from the known test data (exact counts, levels,
  dimensions), not just a class or a loose pattern.
- No conditional assertions such as `if (...) expect_...` — every test
  must always assert something.
- Never wrap the code under test in `try()`, `tryCatch()` or
  `suppressWarnings()`/`suppressMessages()`: an unexpected error or
  warning must fail the test. Assert expected conditions with
  `expect_error()`, `expect_warning()` or `expect_message()` instead.
- Test each error branch once; don't repeat the same check with a
  different bad input unless the input takes a different code path.
- The description states exactly what is asserted, and nothing it
  doesn't assert.
- Use base R, testthat and the packages the package already depends on
  (Imports, Suggests — the existing tests show which); add another
  package (e.g. `withr::`) only where it is clearly the better tool. It
  is then added to Suggests in the suggestion PR.

New tests are added to an existing test file before its clean-up (e.g. a
"shutdown" test or a disconnect at the end), so they can use what the
file sets up at its start. For a test file that doesn't exist yet: if the
package's test files connect or set up at their top level, outside
`test_that()`, give that code as file_setup_code and the matching
clean-up as file_teardown_code; otherwise leave both empty.

## Existing tests

List in existing_tests only the tests that need action; leave out tests
that are fine.

- A **failing** test: decide from the evidence *why* it fails.
  - The function's behavior was changed on purpose — for example the diff
    of the changes under review changes its contract, and the function changed
    after the test — and the test still expects the old behavior: action
    "update", reason "contract_changed". Give the corrected body; the test
    keeps its description.
  - The test describes sensible behavior that the code no longer
    delivers, and nothing shows the change was intended: action "report",
    reason "possible_code_bug". Never adjust a test to match output that
    may be wrong — that would hide the bug.
- A test that duplicates another existing test, tests behavior the
  function no longer has, or asserts nothing meaningful: action "delete"
  with that reason. Don't delete or rewrite a test only because it could
  be written differently.
- Passing tests are not rewritten.

Name each existing test's file (test_file, exactly as listed with the
function's test files) and copy its description exactly. Fill setup_code
and assertions_code only for "update"; use empty strings otherwise.

## Earlier findings

The function's part may list earlier findings of this bot from its open
suggestion PR: existing tests it reported and generated tests that failed
and were not proposed (tests it already added or changed are part of the
function's test files). If there are any: judge each in
`earlier_findings` — still valid, superseded (no longer correct, e.g. the
code changed, or it was wrong) or resolved (the code or tests now do it).
Don't write a new test that does what an earlier failed one did unless
the cause of the failure is gone; if you do, give its id (e.g. "E3") in
`repeats_earlier`. Likewise give the id when you report an existing test
that was reported before. Without earlier findings, leave
`earlier_findings` empty and `repeats_earlier` as empty strings.

## The package's test material

Test setup and helper files, run by testthat before every test file, and
the files they source. Use exactly the objects, data symbols, connection
helpers and helper functions they define — don't invent your own:
{{TEST_SUPPORT_FILES}}

Structure of the test data those files create (rows, columns, types,
missing values, factor level counts) — use it for concrete assertions:
{{TEST_DATA}}

<!-- per function -->
## The function to review

{{ROLE_GUIDANCE}}

Function name: {{FUNCTION_NAME}}

Function source:
{{FUNCTION_SOURCE}}

Existing test files for this function ("(none yet)" means there are none):
{{EXISTING_TEST_FILES}}

How this repository names its test files:
{{TEST_FILE_SCHEME}}

Example test files of other functions, showing how this package writes
its tests — follow how they connect, set up and clean up:
{{EXAMPLE_TEST_FILES}}

Current results of the existing tests, before any change:
{{EXISTING_TEST_RESULTS}}

History of the function and its tests:
{{HISTORY_EVIDENCE}}

Earlier findings of this bot on this function:
{{EARLIER_FINDINGS}}
