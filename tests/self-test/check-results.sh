#!/usr/bin/env bash
# Checks what the self-test runs of the bot workflows produced on the
# fixture r-package with its recorded answers
# (tests/fixtures/claude-answers/r-package.json) — the same expectations
# as tests/testthat/test-entry-scripts.R, but for the workflows as they
# run on GitHub. <dir> holds the downloaded artifacts, one folder each.
#   bash tests/self-test/check-results.sh <dir>
# Prints one line per check and exits non-zero if any failed.
set -uo pipefail

dir="$1"
rox="$dir/self-test-roxygen-r-package"
tst="$dir/self-test-tests-r-package"
passed=0
failed=0
check() {  # check <name> <condition result>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "::error::self-test failed: $1"; failed=$((failed + 1)); fi
}

# Roxygen: add1() gets its @return, clamp() is left alone but its possible
# bug is reported.
[ "$(cat "$rox/updated_files.txt" 2> /dev/null)" = "R/add1.R" ]; check "roxygen: proposes R/add1.R only" $?
grep -q "@return A numeric vector of the same length" "$rox/R/add1.R"; check "roxygen: add1 gets its @return" $?
grep -q "#' @export" "$rox/R/add1.R"; check "roxygen: other tags kept" $?
grep -q "returns hi everywhere when lo > hi" "$rox/suggestion_report.md"; check "roxygen: clamp's possible bug in the report" $?

# Tests: the passing new tests are proposed, the failing one is not, but
# reported.
sort "$tst/updated_files.txt" 2> /dev/null | paste -sd, - | grep -qx "tests/testthat/test-add1.R,tests/testthat/test-clamp.R"
check "tests: proposes test-add1.R and test-clamp.R" $?
grep -q "add1 adds one" "$tst/tests/testthat/test-add1.R"; check "tests: the existing test stays" $?
grep -q "add1 works element-wise on vectors" "$tst/tests/testthat/test-add1.R"; check "tests: new passing test for add1" $?
grep -q "clamp keeps values inside the range" "$tst/tests/testthat/test-clamp.R"; check "tests: new passing test for clamp" $?
[ -f "$tst/tests/testthat/test-clamp.R" ] && ! grep -q "clamp stops when lo is above hi" "$tst/tests/testthat/test-clamp.R"; check "tests: failing test not proposed" $?
grep -q "clamp stops when lo is above hi" "$tst/suggestion_report.md"; check "tests: failing test reported" $?

# Authors (history-r-package.sh): Bea's R change -> aut under her profile
# name, Carl's tests change -> ctb, the bot's commit left out, no e-mails.
aut="$dir/self-test-authors-r-package"
[ "$(cat "$aut/updated_files.txt" 2> /dev/null)" = "DESCRIPTION" ]; check "authors: proposes DESCRIPTION" $?
grep -q 'person("Beatrice", "van Muster", role = "aut")' "$aut/DESCRIPTION"; check "authors: Bea as aut, named from her profile" $?
grep -q 'person("Carl", "Test", role = "ctb")' "$aut/DESCRIPTION"; check "authors: Carl as ctb" $?
[ -f "$aut/DESCRIPTION" ] && ! grep -q 'dependabot\|bea@example.org\|carl@example.org' "$aut/DESCRIPTION"; check "authors: no bot, no e-mails" $?

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
