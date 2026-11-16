#!/usr/bin/env bash
# Judges what sandbox-probe.sh found inside the sandbox (run outside it, by
# sandbox-probe.yml). Writes a table to the step summary and fails if one
# check fails. Usage: judge-probe.sh <probe folder>
set -u
dir="${1:-.probe}"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
fail=0
row() { echo "| $1 | $2 | $3 |" >> "$summary"; [ "$2" = "pass" ] || fail=1; }
read_or() { if [ -f "$1" ]; then tr -d '[:space:]' < "$1"; else echo "$2"; fi; }

{ echo "## Implementer sandbox probe"; echo; echo "| Check | Result | Seen |"; echo "|---|---|---|"; } >> "$summary"

if [ ! -f "$dir/finished" ]; then
  row "The agent ran the probe" fail "no result files: the agent didn't run it, or the sandbox stopped it"
  exit 1
fi
row "The agent ran the probe" pass "result files written"

code=$(read_or "$dir/unlisted.code" 000)
case "$code" in
  2*|3*) row "An unlisted host (example.com) is blocked" fail "HTTP $code: reachable" ;;
  *)     row "An unlisted host (example.com) is blocked" pass "HTTP $code, curl exit $(read_or "$dir/unlisted.exit" unknown)" ;;
esac

code=$(read_or "$dir/allowed.code" 000)
case "$code" in
  2*|3*) row "An allowed host (cloud.r-project.org) is reachable" pass "HTTP $code" ;;
  *)     row "An allowed host (cloud.r-project.org) is reachable" fail "HTTP $code, curl exit $(read_or "$dir/allowed.exit" unknown)" ;;
esac

names=$(tr '\n' ' ' < "$dir/secret-names.txt" 2>/dev/null)
if [ -z "${names// /}" ]; then
  row "No token variable in the agent's shell" pass "none set"
else
  row "No token variable in the agent's shell" fail "set: $names"
fi

n=$(read_or "$dir/token-values.txt" 0)
if [ "$n" = "0" ]; then row "No token-shaped value in the environment" pass "0"; else row "No token-shaped value in the environment" fail "$n variable(s)"; fi

n=$(read_or "$dir/git-header.txt" 0)
if [ "$n" = "0" ]; then row "No stored GitHub credential in git" pass "0"; else row "No stored GitHub credential in git" fail "$n header(s)"; fi

if grep -q "R version" "$dir/r.txt" 2>/dev/null; then
  row "R runs inside the sandbox" pass "$(head -c 60 "$dir/r.txt")"
else
  row "R runs inside the sandbox" fail "$(head -c 120 "$dir/r.txt" 2>/dev/null | tr '\n' ' ')"
fi
exit "$fail"
