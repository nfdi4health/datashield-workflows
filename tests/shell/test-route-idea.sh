#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks in single quotes are meant literally
# Tests for .github/actions/route-idea/, with a stand-in for `gh` that
# records every call. Needs jq.
#   bash tests/shell/test-route-idea.sh
# Prints one line per test and exits non-zero if any failed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.github/actions/route-idea/route-idea.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN"
command -v jq > /dev/null || { echo "FAIL jq is needed"; exit 1; }

passed=0
failed=0
check() {  # check <name> <0 for passed>
  if [ "$2" = 0 ]; then echo "ok   $1"; passed=$((passed + 1)); else echo "FAIL $1"; failed=$((failed + 1)); fi
}

# gh: the hub issue's comment bodies from $WORK/comments; opening an issue
# in the target answers with its URL; every call goes to $WORK/calls, with
# the token it was made with.
cat > "$BIN/gh" <<STANDIN
#!/usr/bin/env bash
printf '%s | token=%s\n' "\$*" "\$GH_TOKEN" >> "$WORK/calls"
case "\$*" in
  *"--paginate"*) cat "$WORK/comments" ;;
  "api repos/target-owner/dsCluster/issues "*) echo "https://github.com/target-owner/dsCluster/issues/7" ;;
esac
STANDIN
chmod +x "$BIN/gh"

ROUTES='# routing labels
dsClusterAnalysis = target-owner/dsCluster
dsSurvival=other/dsSurvival'

# run <step> <sender> <label>: an issue whose title and body try to run code
# and mention someone.
run() {
  : > "$WORK/calls"; : > "$WORK/out"
  jq -n --arg sender "$2" --arg label "$3" '{action: "labeled", sender: {login: $sender}, label: {name: $label},
    issue: {number: 12, title: "k-medoids $(touch pwned)", html_url: "https://github.com/hub/ideas/issues/12",
            body: "Needed for @someone in `x`"}}' > "$WORK/event.json"
  PATH="$BIN:$PATH" GITHUB_EVENT_PATH="$WORK/event.json" GITHUB_REPOSITORY=hub/ideas GITHUB_OUTPUT="$WORK/out" \
    GH_TOKEN=hub-token ROUTES="$ROUTES" ALLOWED_LOGINS="maintainer, other" TARGET=target-owner/dsCluster \
    TARGET_TOKEN=app-token ROUTED_LABEL=routed bash "$SCRIPT" "$1" > "$WORK/log" 2>&1
}

: > "$WORK/comments"
run plan maintainer DSCLUSTERANALYSIS
grep -qx "target=target-owner/dsCluster" "$WORK/out" && grep -qx "owner=target-owner" "$WORK/out" && grep -qx "repo=dsCluster" "$WORK/out"
check "an allowed login's routing label gives the target (label case ignored)" $?

run plan maintainer enhancement
rc=1; if [ ! -s "$WORK/out" ] && [ ! -s "$WORK/calls" ]; then rc=0; fi
check "another label does nothing" "$rc"

run plan stranger dsSurvival
rc=1; if [ ! -s "$WORK/out" ] && grep -q "DELETE repos/hub/ideas/issues/12/labels/dsSurvival" "$WORK/calls" \
  && grep -q "only the people named" "$WORK/calls"; then rc=0; fi
check "a routing label set by anyone else is removed, with a comment" "$rc"

echo 'Tracked in target-owner/dsCluster#7.

<!-- routed-to: target-owner/dsCluster -->' > "$WORK/comments"
run plan maintainer dsClusterAnalysis
rc=1; if [ ! -s "$WORK/out" ] && grep -q "Already copied" "$WORK/log"; then rc=0; fi
check "an idea already copied there is not copied again" "$rc"

: > "$WORK/comments"
run copy maintainer dsClusterAnalysis
grep -q "api repos/target-owner/dsCluster/issues .* | token=app-token" <(tr '\n' ' ' < "$WORK/calls")
check "the copy is opened with the App token" $?
grep -q "issues/12/comments .*Tracked in target-owner/dsCluster#7.*routed-to: target-owner/dsCluster.* | token=hub-token" <(tr '\n' ' ' < "$WORK/calls")
check "the hub issue gets the link and the marker, with the hub's token" $?
grep -q "issues/12/labels -f labels\[\]=routed" "$WORK/calls"
check "the hub issue gets the routed label" $?
rc=1; if grep -q "Copied from https://github.com/hub/ideas/issues/12" "$WORK/calls" && grep -q 'function-idea: hub/ideas#12' "$WORK/calls"; then rc=0; fi
check "the copy links back to the hub issue" "$rc"
rc=1; if ! grep -q "for @someone" "$WORK/calls" && [ ! -e pwned ] && [ ! -e "$WORK/pwned" ]; then rc=0; fi
check "mentions are defused and the title is never run" "$rc"

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
