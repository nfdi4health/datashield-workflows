#!/usr/bin/env bash
# Self-test runs of the bot workflows (input self-test-fixture): puts the
# fixture package tests/fixtures/<name> in place of the caller's
# checkout — copied into the workspace and committed as a fresh git
# repository, since the bots read the history and the reviewed commit.
# With "history" as second argument, history-<name>.sh next to this
# script adds commits by several authors on top (the authors bot).
#   bash .shared-workflows/tests/self-test/use-fixture.sh r-package [history]
set -euo pipefail

fixture=".shared-workflows/tests/fixtures/$1"
if [ ! -d "$fixture" ]; then
  echo "::error::There is no fixture '$1' in tests/fixtures/."
  exit 1
fi
cp -R "$fixture/." .
git init -q -b main .
printf '.shared-workflows/\n' >> .git/info/exclude
git -c user.name=self-test -c user.email=self-test@example.invalid add -A
git -c user.name=self-test -c user.email=self-test@example.invalid commit -qm "Fixture $1"
if [ "${2:-}" = "history" ]; then
  bash "$(dirname "$0")/history-$1.sh"
fi
echo "Self-test on the fixture $1 ($(git ls-files | wc -l) files)."
