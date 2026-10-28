#!/usr/bin/env bash
# Commits on top of the fixture r-package for the authors bot's
# self-test, run by use-fixture.sh in the workspace: an R change by Bea
# (her login and profile name are recorded in
# tests/fixtures/claude-answers/r-package.json) → aut, a tests-only change
# by Carl (no GitHub account) → ctb, and a bot commit that is left out.
set -euo pipefail

commit() {  # commit <file> <line> <author name> <e-mail>
  printf '%s\n' "$2" >> "$1"
  git add -A
  git -c "user.name=$3" -c "user.email=$4" commit -qm "Change $1"
}
commit R/clamp.R "# note" "Bea M" "bea@example.org"
commit tests/testthat/test-add1.R "# note" "Carl Test" "carl@example.org"
commit R/add1.R "# bump" "dependabot[bot]" "bot@example.org"
