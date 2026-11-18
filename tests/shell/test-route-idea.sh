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
  *"idea-check"*) cat "$WORK/checks" 2> /dev/null ;;
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

# The hub's check comment goes along, the newest one, without its markers
# and note; a person's comment never does (the stand-in gets what the jq
# filter would keep: bots' check comments, base64, oldest first).
: > "$WORK/comments"
{ printf '**Exists in DataSHIELD?**\n\nOld verdict.\n<!-- idea-check: none -->\n' | base64 -w0; echo
  printf '**Exists in DataSHIELD?**\n\nPartly: `dsX::ds.y` ping @someone.\n\n<sub>delete this comment to have it run again</sub>\n\n<!-- idea-check: partial -->\n<!-- literature-watch-method: k-medoids -->\n' | base64 -w0; echo; } > "$WORK/checks"
run copy maintainer dsClusterAnalysis
calls="$(cat "$WORK/calls")"
rc=1; if grep -q "The hub's check of this idea, when it was routed" <<< "$calls" && grep -q 'Partly: `dsX::ds.y`' <<< "$calls" \
  && ! grep -q "Old verdict" <<< "$calls" && ! grep -q "idea-check: partial" <<< "$calls" \
  && ! grep -q "literature-watch-method" <<< "$calls" && ! grep -q "run it again\|have it run again" <<< "$calls" \
  && ! grep -q "ping @someone" <<< "$calls"; then rc=0; fi
check "the newest check comment goes into the copy, without markers, note or live mentions" "$rc"
rm -f "$WORK/checks"
run copy maintainer dsClusterAnalysis
rc=1; if ! grep -q "The hub's check" "$WORK/calls"; then rc=0; fi
check "without a check comment the copy has no check section" "$rc"

# labels: creates the route labels the hub lacks (the stand-in answers the
# label list from $WORK/comments), leaves existing ones alone.
printf 'dsSurvival\nbug\n' > "$WORK/comments"
run labels maintainer x
rc=1; if grep -q 'api repos/hub/ideas/labels -f name=dsClusterAnalysis -f color=1d76db -f description=Route to target-owner/dsCluster' "$WORK/calls" \
  && ! grep -q 'name=dsSurvival' "$WORK/calls"; then rc=0; fi
check "labels: missing route labels are created, existing ones (any case) left alone" "$rc"

# routes from a file, when ROUTES is empty
cat > "$WORK/routes.yml" <<'YAML'
# Routing labels
routes:
  dsClusterAnalysis: target-owner/dsCluster   # client
  dsSupportClient: owner/dsSupportClient
YAML
: > "$WORK/comments"; : > "$WORK/calls"; : > "$WORK/out"
jq -n '{action: "labeled", sender: {login: "maintainer"}, label: {name: "dssupportclient"}, issue: {number: 12}}' > "$WORK/event.json"
PATH="$BIN:$PATH" GITHUB_EVENT_PATH="$WORK/event.json" GITHUB_REPOSITORY=hub/ideas GITHUB_OUTPUT="$WORK/out" \
  GH_TOKEN=hub-token ROUTES="" ROUTES_FILE="$WORK/routes.yml" ALLOWED_LOGINS=maintainer bash "$SCRIPT" plan > "$WORK/log" 2>&1
grep -qx "target=owner/dsSupportClient" "$WORK/out"
check "routes come from the file when the input is empty" $?
rc=1; if ! ROUTES="" ROUTES_FILE="$WORK/missing.yml" GITHUB_EVENT_PATH="$WORK/event.json" bash "$SCRIPT" plan > /dev/null 2>&1; then rc=0; fi
check "a missing routes file stops the run" "$rc"

# sync: a stand-in gh answering the hub's routed issues, their comments
# and the copies' states from files in $WORK/sync.
sync_run() {  # sync_run: runs the sync step with the files in $WORK/sync
  : > "$WORK/calls"
  PATH="$WORK/syncbin:$PATH" GITHUB_REPOSITORY=hub/ideas GH_TOKEN=hub-token RUNNER_TEMP="$WORK" \
    GITHUB_EVENT_PATH=/dev/null ROUTED_LABEL=routed DECLINED_LABEL=declined bash "$SCRIPT" sync > "$WORK/log" 2>&1
}
mkdir -p "$WORK/syncbin" "$WORK/sync"
cat > "$WORK/syncbin/gh" <<STANDIN
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WORK/calls"
case "\$*" in
  *"repos/hub/ideas/issues?state=all"*) cat "$WORK/sync/routed" ;;
  *"repos/hub/ideas/issues/"*"/comments?per_page=100"*) n="\$(printf '%s' "\$*" | sed -E 's|.*issues/([0-9]+)/comments.*|\1|')"; cat "$WORK/sync/comments-\$n" 2>/dev/null ;;
  "api repos/target/pkg/issues/"*" --jq"*) n="\${2##*/}"; f="$WORK/sync/copy-\$n"; [ -f "\$f" ] && cat "\$f" || exit 1 ;;
esac
STANDIN
chmod +x "$WORK/syncbin/gh"

# Issue 12 routed to target/pkg#7, now closed as completed; issue 13 routed
# to target/pkg#8, closed as not planned; issue 14's copy #9 unchanged.
printf '12 open \n13 open \n14 open \n' > "$WORK/sync/routed"
printf 'Tracked in target/pkg#7: discussion and work happen there.\n<!-- routed-to: target/pkg -->\n' > "$WORK/sync/comments-12"
printf 'Tracked in target/pkg#8: discussion and work happen there.\n' > "$WORK/sync/comments-13"
printf 'Tracked in target/pkg#9: discussion and work happen there.\n' > "$WORK/sync/comments-14"
echo "closed completed" > "$WORK/sync/copy-7"
echo "closed not_planned" > "$WORK/sync/copy-8"
echo "open " > "$WORK/sync/copy-9"
sync_run
calls="$(tr '\n' ' ' < "$WORK/calls")"
rc=1; if grep -q 'issues/12/comments -f body=Done: target/pkg#7 was closed as completed.*This idea is closed here with it.*route-status: target/pkg#7 completed' <<< "$calls" \
  && grep -q 'PATCH repos/hub/ideas/issues/12 -f state=closed -f state_reason=completed' <<< "$calls"; then rc=0; fi
check "sync: a copy closed as completed closes the hub issue, with one comment" "$rc"
rc=1; if grep -q 'issues/13/comments -f body=target/pkg#8 was closed there as not planned.*route-status: target/pkg#8 not-planned' <<< "$calls" \
  && grep -q 'issues/13/labels -f labels\[\]=declined' <<< "$calls" && ! grep -q 'PATCH repos/hub/ideas/issues/13' <<< "$calls"; then rc=0; fi
check "sync: a copy closed as not planned labels the hub issue, which stays open" "$rc"
rc=1; if ! grep -q 'issues/14/comments -f' <<< "$calls"; then rc=0; fi
check "sync: nothing changed, nothing written" "$rc"

# The next run: the states are recorded, so nothing is written again; then
# copy #7 is reopened and the hub issue (closed as completed) opens again.
printf '12 closed completed\n13 open \n' > "$WORK/sync/routed"
printf 'Tracked in target/pkg#7: x\nDone.\n<!-- route-status: target/pkg#7 completed -->\n' > "$WORK/sync/comments-12"
printf 'Tracked in target/pkg#8: x\n<!-- route-status: target/pkg#8 not-planned -->\n' > "$WORK/sync/comments-13"
sync_run
rc=1; if ! grep -q -- '-f body=' "$WORK/calls" && ! grep -q PATCH "$WORK/calls"; then rc=0; fi
check "sync: a recorded state is not reported twice" "$rc"
echo "open " > "$WORK/sync/copy-7"
echo "open " > "$WORK/sync/copy-8"
sync_run
calls="$(tr '\n' ' ' < "$WORK/calls")"
rc=1; if grep -q 'issues/12/comments -f body=target/pkg#7 was reopened' <<< "$calls" && grep -q 'PATCH repos/hub/ideas/issues/12 -f state=open' <<< "$calls" \
  && grep -q 'DELETE repos/hub/ideas/issues/13/labels/declined' <<< "$calls"; then rc=0; fi
check "sync: a reopened copy reopens the hub issue and removes the declined label" "$rc"

echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
