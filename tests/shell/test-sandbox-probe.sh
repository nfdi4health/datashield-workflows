#!/usr/bin/env bash
# Tests judge-probe.sh (sandbox-probe.yml) on made-up probe files.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
judge="$here/../../.github/actions/implementer/judge-probe.sh"
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (expected $3, got $2)"; failures=$((failures + 1)); fi; }

setup() {
  dir="$(mktemp -d)"
  echo finished > "$dir/finished"; echo 000 > "$dir/unlisted.code"; echo 56 > "$dir/unlisted.exit"
  echo 200 > "$dir/allowed.code"; : > "$dir/secret-names.txt"; echo 0 > "$dir/token-values.txt"
  echo 0 > "$dir/git-header.txt"; echo "R version 4.6.2" > "$dir/r.txt"
}
judge() { GITHUB_STEP_SUMMARY="$dir/summary.md" bash "$judge" "$dir" > /dev/null 2>&1; echo $?; }

setup; check "all good passes" "$(judge)" 0
setup; echo 200 > "$dir/unlisted.code"; check "a reachable unlisted host fails" "$(judge)" 1
setup; echo 403 > "$dir/unlisted.code"; check "a refusal by the proxy counts as blocked" "$(judge)" 0
setup; echo 000 > "$dir/allowed.code"; check "an unreachable allowed host fails" "$(judge)" 1
setup; echo GITHUB_TOKEN > "$dir/secret-names.txt"; check "a token variable fails" "$(judge)" 1
setup; echo 1 > "$dir/token-values.txt"; check "a token-shaped value fails" "$(judge)" 1
setup; echo 1 > "$dir/git-header.txt"; check "a stored git credential fails" "$(judge)" 1
setup; echo "Rscript: command not found" > "$dir/r.txt"; check "R not running fails" "$(judge)" 1
setup; rm "$dir/finished"; check "no result files fails" "$(judge)" 1
setup; judge > /dev/null; check "the summary names each check" "$(grep -c '| pass |' "$dir/summary.md")" 7

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "all passed"
