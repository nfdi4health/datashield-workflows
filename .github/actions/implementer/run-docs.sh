#!/usr/bin/env bash
# Around the documentation step at the end of a run
# (prompts/implementer-roxygen.md). Usage: run-docs.sh scope|verdict, with
# START = the commit before that step.
#   scope    keeps its commits only if the step finished (AGENT_OUTCOME) and they change nothing but `#'` lines in
#            R/, man/ and the RoxygenNote in DESCRIPTION; keeps a copy of
#            the checks before it. Output changed=true|false.
#   verdict  after the checks ran again: if they pass no longer, the
#            documentation commits are dropped and the earlier checks
#            restored.
# Writes .agent/docs.md for the pull request. Never fails the step.
set -uo pipefail
mkdir -p .agent
mode="${1:-scope}"

drop() {
  git reset -q --hard "$START"
  echo "$1" > .agent/docs.md
}

if [ "$mode" = scope ]; then
  echo "changed=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  if [ "${AGENT_OUTCOME:-success}" != success ]; then
    drop "The documentation step didn't finish, so its work was left out."
    exit 0
  fi
  if [ "$(git rev-parse HEAD)" = "$START" ]; then
    echo "The documentation needed no update." > .agent/docs.md
    exit 0
  fi
  files="$(git diff --name-only "$START" HEAD)"
  bad="$(grep -vE '^(R/[^/]+\.[Rr]|man/[^/]+\.Rd|DESCRIPTION)$' <<< "$files" || true)"
  # Changed lines in R/ must be roxygen lines, in DESCRIPTION the RoxygenNote.
  bad_lines="$(git diff -U0 "$START" HEAD -- R DESCRIPTION | grep -E '^[-+][^-+]' | grep -vE "^[-+][[:space:]]*#'|^[-+]RoxygenNote:" || true)"
  if [ -n "$bad" ] || [ -n "$bad_lines" ]; then
    drop "The documentation step changed more than documentation, so its work was left out."
    exit 0
  fi
  for f in checks.md checks.json; do [ -f ".agent/$f" ] && cp ".agent/$f" ".agent/before-docs-$f"; done
  # shellcheck disable=SC2016 # backticks are Markdown
  echo "The documentation step updated: $(sed 's/^/`/; s/$/`/' <<< "$files" | paste -sd ' ')." > .agent/docs.md
  echo "changed=true" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# verdict
before_ok="$(jq -r '.ok' .agent/before-docs-checks.json 2> /dev/null || echo true)"
now_ok="$(jq -r '.ok' .agent/checks.json 2> /dev/null || echo true)"
if [ "$before_ok" = true ] && [ "$now_ok" != true ]; then
  drop "The documentation update made the checks fail, so it was left out; the documentation needs a look by hand."
  for f in checks.md checks.json; do [ -f ".agent/before-docs-$f" ] && cp ".agent/before-docs-$f" ".agent/$f"; done
fi
exit 0
