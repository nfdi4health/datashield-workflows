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
if [ "$1" = "report.R" ]; then echo "${HUB_TOKEN:-unset}" > report_env; [ -f report_fails ] && exit 1; exit 0; fi
n=$(cat calls 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > calls
echo "${HUB_TOKEN:-unset} ${WATCH_MAX_PAPERS:-empty}" >> rscript_env
line=$(sed -n "${n}p" answers)
[ "$line" = "error" ] && exit 1
set -- $line
printf '{"stopped":"%s","read":%s,"remaining":%s,"progress":"p%s"}' "$1" "$2" "$3" "$n" > watch_status.json
STUB
  cat > "$work/bin/git" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> git_calls
case "$*" in *"diff --cached --quiet"*) exit 1 ;; esac
exit 0
STUB
  chmod +x "$work/bin/"*
  [ -n "${REPORT_FAILS:-}" ] && touch "$work/report_fails"
  (cd "$work" && PATH="$work/bin:$PATH" HUB_TOKEN="${2:-}" DATA_BRANCH=data SCRIPT=x.R REPORT_SCRIPT="${3:-}" MAX_PAPERS="" \
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

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "all passed"
