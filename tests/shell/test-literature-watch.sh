#!/usr/bin/env bash
# Tests read-loop.sh (literature-watch.yml): stand-ins for Rscript (one
# watch_status.json per call, from a script of answers) and git (records
# its arguments), so the loop's decisions are checked without R or GitHub.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
loop="$here/../../.github/actions/literature-watch/read-loop.sh"
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (expected $3, got $2)"; failures=$((failures + 1)); fi; }

# run_loop <answers, one "stopped read remaining" per line> [token] [report script]
run_loop() {
  work="$(mktemp -d)"
  mkdir -p "$work/bin" "$work/watch-data"
  printf '%s\n' "$1" > "$work/answers"
  cat > "$work/bin/Rscript" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "classify.R" ]; then echo "${HUB_TOKEN:-unset}" > classify_env; [ -f classify_fails ] && exit 1; exit 0; fi
if [ "$1" = "report.R" ]; then echo "${HUB_TOKEN:-unset}" > report_env; [ -f report_fails ] && exit 1; exit 0; fi
n=$(cat calls 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > calls
echo "${HUB_TOKEN:-unset} ${WATCH_MAX_PAPERS:-empty} ${APP_PRIVATE_KEY:-nokey}" >> rscript_env
line=$(sed -n "${n}p" answers)
[ "$line" = "error" ] && exit 1
set -- $line
printf '{"stopped":"%s","read":%s,"remaining":%s,"progress":"p%s"}' "$1" "$2" "$3" "$n" > watch_status.json
STUB
  cat > "$work/bin/git" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> git_calls
case "$*" in *"diff --cached --quiet"*) exit 1 ;; esac
case "$*" in *" push "*) if [ -f push_fails_once ]; then rm push_fails_once; exit 1; fi ;; esac
exit 0
STUB
  chmod +x "$work/bin/"*
  [ -n "${REPORT_FAILS:-}" ] && touch "$work/report_fails"
  [ -n "${CLASSIFY_FAILS:-}" ] && touch "$work/classify_fails"
  [ -n "${PUSH_FAILS_ONCE:-}" ] && touch "$work/push_fails_once"
  (cd "$work" && PATH="$work/bin:$PATH" HUB_TOKEN="${2:-}" DATA_BRANCH=data SCRIPT=x.R REPORT_SCRIPT="${3:-}" CLASSIFY_SCRIPT="${4:-}" MAX_PAPERS="" \
    GITHUB_OUTPUT="$work/out" GITHUB_STEP_SUMMARY="$work/summary" bash "$loop" > /dev/null 2>&1; echo $? > "$work/exit")
}

run_loop $'chunk 250 1250\nchunk 250 1000\nbudget 250 750' secret
check "the loop goes on while a stretch says chunk" "$(cat "$work/calls")" 3
check "it ends with the last stretch's state" "$(grep stopped "$work/out")" "stopped=budget"
check "R never sees the hub token" "$(cut -d' ' -f1 "$work/rscript_env" | sort -u)" "unset"
check "the next stretch gets what's left of the budget" "$(sed -n 2p "$work/rscript_env" | cut -d' ' -f2)" "1250"
check "each stretch is pushed" "$(grep -c 'push --quiet origin HEAD:refs/heads/data' "$work/git_calls")" 3
check "the push carries the token in a header, not the URL" "$(grep -c 'extraheader=AUTHORIZATION: basic' "$work/git_calls")" 3
check "a run that stops normally succeeds" "$(cat "$work/exit")" 0

run_loop 'limit 40 1460' secret
check "the usage limit ends the loop" "$(cat "$work/calls")" 1
check "and is reported" "$(grep -c 'usage limit' "$work/summary")" 1

run_loop $'chunk 250 1250\nerror' secret
check "an error ends the loop" "$(cat "$work/calls")" 2
check "what was read before is pushed" "$(grep -c 'push --quiet' "$work/git_calls")" 2
check "and the step fails" "$(cat "$work/exit")" 1

run_loop 'done 3 1497' ''
check "without a hub token nothing is pushed" "$(grep -c push "$work/git_calls" 2>/dev/null || echo 0)" 0

run_loop $'chunk 250 1250\nbudget 250 1000' secret report.R
check "the report is built after the reading" "$(cat "$work/report_env")" "unset"
check "and pushed as one more commit" "$(grep -c 'push --quiet origin HEAD:refs/heads/data' "$work/git_calls")" 3
check "with its own message" "$(grep -c 'literature watch, report' "$work/git_calls")" 1

REPORT_FAILS=1 run_loop 'done 3 1497' secret report.R
check "a report that fails fails the step" "$(cat "$work/exit")" 1

run_loop $'budget 250 1250' secret report.R classify.R
check "the vocabulary step runs after the reading, without the hub token" "$(cat "$work/classify_env")" "unset"
check "and is pushed as its own commit" "$(grep -c 'literature watch, vocabulary' "$work/git_calls")" 1
check "before the report" "$(grep -c 'literature watch, report' "$work/git_calls")" 1

run_loop 'limit 40 1460' secret report.R classify.R
check "at the usage limit the vocabulary step waits" "$([ -f "$work/classify_env" ] && echo ran || echo skipped)" skipped

CLASSIFY_FAILS=1 run_loop 'done 3 1497' secret report.R classify.R
check "a failed vocabulary step still gives a report" "$(grep -c 'literature watch, report' "$work/git_calls")" 1
check "and doesn't fail the step" "$(cat "$work/exit")" 0

PUSH_FAILS_ONCE=1 run_loop 'done 3 1497' secret
check "a rejected push is put on top of the branch and pushed again" "$(grep -c 'pull --quiet --rebase origin data' "$work/git_calls")" 1
check "and the run goes on" "$(cat "$work/exit")" 0

# The hub token lasts an hour: with the App's ID and key, push() gets a new
# one once the old one is TOKEN_RENEW_SECONDS old (here at once).
stub_dir="$(mktemp -d)"
printf '#!/usr/bin/env bash\necho fresh-token\n' > "$stub_dir/new-token.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$stub_dir/no-token.sh"
fresh_header="AUTHORIZATION: basic $(printf 'x-access-token:%s' fresh-token | base64 -w0)"
APP_CLIENT_ID=client APP_PRIVATE_KEY=the-key TOKEN_RENEW_SECONDS=0 HUB_TOKEN_SCRIPT="$stub_dir/new-token.sh" \
  run_loop $'chunk 250 1250\nbudget 250 1000' old-token report.R
check "an old token is renewed before each push" "$(grep -c "extraheader=$fresh_header" "$work/git_calls")" 3
old_header="AUTHORIZATION: basic $(printf 'x-access-token:%s' old-token | base64 -w0)"
check "and the old one isn't used again" "$(grep -c "extraheader=$old_header" "$work/git_calls")" 0
check "R never sees the App's key" "$(cut -d' ' -f3 "$work/rscript_env" | sort -u)" "nokey"
check "nor the renewed token" "$(cat "$work/report_env")" "unset"
APP_CLIENT_ID=client APP_PRIVATE_KEY=the-key TOKEN_RENEW_SECONDS=3600 HUB_TOKEN_SCRIPT="$stub_dir/new-token.sh" \
  run_loop 'budget 250 1250' old-token
check "a young token is kept" "$(grep -c 'fresh-token\|extraheader=AUTHORIZATION: basic' "$work/git_calls")" 1
APP_CLIENT_ID=client APP_PRIVATE_KEY=the-key TOKEN_RENEW_SECONDS=0 HUB_TOKEN_SCRIPT="$stub_dir/no-token.sh" \
  run_loop 'budget 250 1250' old-token
check "a failed renewal keeps the old token and goes on" "$(cat "$work/exit")" 0

# tracked-ideas.sh: the markers of the hub's issues, with a stand-in for gh.
tracked="$here/../../.github/actions/literature-watch/tracked-ideas.sh"
work="$(mktemp -d)"
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' '[{"number":3,"body":"x <!-- literature-watch-method: fine-gray -->"},{"number":4,"pull_request":{},"body":"<!-- literature-watch-method: pr-only -->"}]'
printf '%s\n' '[{"number":9,"body":null},{"number":12,"body":"<!--literature-watch-method: cox-regression/tvc -->"}]'
STUB
chmod +x "$work/bin/gh"
(cd "$work" && PATH="$work/bin:$PATH" HUB=o/hub GH_TOKEN=t bash "$tracked" out.json > /dev/null)
check "tracked ideas: markers of issues on every page, not of pull requests" "$(jq -c . "$work/out.json")" '{"fine-gray":3,"cox-regression/tvc":12}'
(cd "$work" && HUB="" bash "$tracked" none.json > /dev/null)
check "without a hub: an empty list" "$(cat "$work/none.json")" "{}"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "all passed"
