#!/usr/bin/env bash
# Tests for the scope and change-detection scripts of
# .github/actions/resolve-suggestion-scope/, in throwaway git repositories,
# with a stand-in for `gh` (and for `jq` and `yq` where they aren't installed).
#   bash tests/shell/test-scope.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCOPE="$ROOT/.github/actions/resolve-suggestion-scope"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN"
command -v jq > /dev/null || printf '#!/usr/bin/env bash\n' > "$BIN/jq"   # event fields: none
command -v yq > /dev/null || printf '#!/usr/bin/env bash\n' > "$BIN/yq"   # bot-authors lists: none
chmod +x "$BIN"/* 2> /dev/null || true
echo '{}' > "$WORK/event.json"
echo '{}' > "$WORK/bot.yml"

passed=0
failed=0
check() {  # check <name> <condition result>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "FAIL $1"; failed=$((failed + 1)); fi
}
g() { git -c user.email=t@t -c user.name=dev "$@"; }

# --- resolve-suggestion-scope.sh --------------------------------------------------

scope() {  # scope <event> <ref_name> <review_scope> <allow_scheduled> <review_branch> [head_ref]
  : > "$WORK/out.txt"
  PATH="$BIN:$PATH" GITHUB_EVENT_NAME="$1" GITHUB_EVENT_PATH="$WORK/event.json" GITHUB_OUTPUT="$WORK/out.txt" \
    GITHUB_REF="refs/heads/$2" REF_NAME="$2" HEAD_REF="${6:-}" ACTOR=someone \
    REVIEW_SCOPE="$3" ALLOW_SCHEDULED="$4" REVIEW_BRANCH="$5" GITHUB_REPOSITORY=me/pkg \
    bash "$SCOPE/resolve-suggestion-scope.sh" > /dev/null 2>&1
  cat "$WORK/out.txt"
}
out="$(scope schedule main changed true "")";            grep -qx "mode=changed" <<< "$out" && grep -qx "branch=dev" <<< "$out"; check "schedule: changed on dev" $?
out="$(scope workflow_dispatch feature changed true "")"; grep -qx "branch=feature" <<< "$out"; check "manual run: the chosen branch" $?
out="$(scope workflow_dispatch main all true "")";     grep -qx "mode=all" <<< "$out"; check "review-scope all: full review" $?
out="$(scope schedule main changed false "")";            grep -qx "skip=true" <<< "$out"; check "authors: no scheduled runs" $?
out="$(scope pull_request x changed true "" bot-suggest/tests/dev)"; grep -qx "skip=true" <<< "$out"; check "bot branch skipped" $?

# --- determine-changes.sh with review-history.sh ------------------------------------

repo="$WORK/repo"
mkdir -p "$repo/R" && cd "$repo" || exit 1
git init -q -b dev .
echo a > R/a.R; echo b > R/b.R; g add -A; g commit -qm c1
echo a2 > R/a.R; g commit -qam c2; c2=$(git rev-parse HEAD)
git checkout -qb feature; echo c > R/c.R; g add -A; g commit -qm c3; c3=$(git rev-parse HEAD)
git checkout -q dev; g merge -q --no-ff feature -m "Merge feature"; git branch -qD feature
echo d > R/d.R; g add -A; g commit -qm c4

# gh: an earlier review of dev at c2 (b.R failed there), then a reviewed PR (c.R).
cat > "$BIN/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  "pr list"*) ;;
  *"/actions/workflows/"*) printf '200\tpull_request\t$c2\n100\tschedule\t\n' ;;
  *"/runs/200/jobs"*) echo 2001 ;;
  *"/runs/100/jobs"*) echo 1001 ;;
  *"/check-runs/2001/annotations"*) printf 'bot-suggest review\t.github\ttests feature $c3\n' ;;
  *"/check-runs/1001/annotations"*) printf 'bot-suggest review\t.github\ttests dev $c2\nSuggestion not made\tR/b.R\tClaude call failed\n' ;;
esac
EOF
chmod +x "$BIN/gh"

changes() {  # changes <event> <workflow ref>
  : > "$WORK/out.txt"
  PATH="$BIN:$PATH" GITHUB_EVENT_NAME="$1" GITHUB_EVENT_PATH="$WORK/event.json" GITHUB_OUTPUT="$WORK/out.txt" \
    GITHUB_REPOSITORY=me/pkg GITHUB_WORKFLOW_REF="me/pkg/.github/workflows/test-suggest.yml@$2" GITHUB_RUN_ID=300 \
    BRANCH=dev SUB_BRANCH=bot-suggest/tests/dev FILE_PATTERN='R/*.R' BOT_CONFIG="$WORK/bot.yml" \
    bash "$SCOPE/determine-changes.sh" > /dev/null 2>&1
}
changes workflow_dispatch refs/heads/dev
[ "$(paste -sd, files_to_check.txt)" = "R/b.R,R/d.R" ]; check "manual run: changes since the last review, its failed file, not the PR's" $?
grep -qx "count=2" "$WORK/out.txt"; check "manual run: count" $?
[ ! -e history_failed.txt ] && [ ! -e history_pr.txt ]; check "no temporary files left" $?

printf '#!/usr/bin/env bash\n' > "$BIN/gh"   # no earlier runs
changes schedule refs/heads/main
[ ! -s files_to_check.txt ] && grep -qx "count=0" "$WORK/out.txt"; check "first scheduled run: nothing, becomes the starting point" $?

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
