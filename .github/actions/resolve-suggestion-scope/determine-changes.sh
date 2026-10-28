#!/usr/bin/env bash
# Works out what is new since the last suggestion run on a branch, after
# checkout (fetch-depth: 0). Design: dev-notes/suggestions-trigger-model.md.
#
# Starting point, first match wins:
#   1. the marker "<!-- bot-suggest: reviewed up to <sha> -->" in the open
#      bot PR's description (catches up dropped or failed runs);
#   2. a PR that was opened or reopened: the PR's base (the whole PR);
#   3. the event's "before" (push, PR synchronize);
#   4. a scheduled or manual run: the last review of this branch, from the
#      run history (review-history.sh); none yet: nothing to review, this
#      run becomes the starting point (a full review is review-scope "all");
#   5. none (a new branch): commits that exist on no other branch.
# Files named in "<!-- bot-suggest: retry <file> -->" lines of the open bot
# PR, or (4.) in that last review's "Suggestion not made" warnings — their
# Claude call failed — are checked again in any case.
# Runs other than pull requests count only commits on no other branch, so
# commits merged in from dev aren't reviewed or credited, and leave out
# commits a pull request run of this workflow already reviewed (from the
# run history, so this also holds once the PR's branch is deleted). Merge
# commits and the bot's own commits (author or subject, from
# bot-authors.yml) are left out. If the history was rewritten (the
# starting point is no ancestor of HEAD), rebuild=true: the bot branch
# can't be built on.
#
# Env: BRANCH, SUB_BRANCH (the bot branch for BRANCH), FILE_PATTERN
# (pathspec like 'R/*.R'; empty: commits only), BOT_CONFIG (path to the shared
# bot-authors.yml), GH_TOKEN, plus GITHUB_EVENT_NAME, GITHUB_EVENT_PATH.
# Writes commits.txt (one sha per line), files_to_check.txt (FILE_PATTERN
# matches still present at HEAD), and count, base_rev, rebuild,
# reviewed_sha to GITHUB_OUTPUT.
set -eo pipefail

out() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }
field() { jq -r "$1 // empty" "$GITHUB_EVENT_PATH"; }
exists() { git cat-file -e "$1^{commit}" 2>/dev/null; }
is_ancestor() { git merge-base --is-ancestor "$1" HEAD 2>/dev/null; }
is_ancestor_of() { git merge-base --is-ancestor "$1" "$2" 2>/dev/null; }
zeros="0000000000000000000000000000000000000000"

head="$(git rev-parse HEAD)"
event="$GITHUB_EVENT_NAME"
action="$(field '.action')"
rebuild=false
start=""
range_is_pr=false
from_history=false

# 1. Marker in the open bot PR
body="$(gh pr list --head "$SUB_BRANCH" --state open --json body --jq '.[0].body // empty' 2>/dev/null || true)"
# (No marker is the normal case for a first run: grep finding nothing must not end the script.)
marker="$(printf '%s' "$body" | { grep -oE 'bot-suggest: reviewed up to [0-9a-f]{7,40}' || true; } | tail -1 | awk '{print $NF}')"
if [ -n "$marker" ]; then
  if exists "$marker" && is_ancestor "$marker"; then
    start="$marker"
    echo "Continuing from the open bot PR's marker ($marker)."
  else
    echo "The marker $marker isn't in this branch's history any more (rewritten); rebuilding the bot branch."
    rebuild=true
  fi
fi

# Earlier reviews of this workflow (run history): every run but a pull
# request's, for 4. and for leaving out what PR runs already reviewed.
history_start=""   # set by review-history.sh
history_run=""
: > history_failed.txt
: > history_pr.txt
if [ "$event" != "pull_request" ]; then
  KIND="${SUB_BRANCH#bot-suggest/}"; KIND="${KIND%%/*}"
  # shellcheck source=.github/actions/resolve-suggestion-scope/review-history.sh
  source "$(dirname "$0")/review-history.sh"
fi

# 2./3. The event
if [ -z "$start" ] && [ "$event" != "pull_request" ] && [ "$event" != "push" ]; then
  # 4. A scheduled or manual run
  if [ -n "$history_start" ]; then
    start="$history_start"
    from_history=true
    echo "Changes since the last review of $BRANCH (run $history_run, ${start:0:7})."
  else
    start="$head"
    echo "::notice::No earlier review of $BRANCH found in this workflow's runs: nothing to review now, this run is the starting point. For a full review, run it with review-scope \"all\"."
  fi
elif [ -z "$start" ]; then
  if [ "$event" = "pull_request" ] && { [ "$action" = "opened" ] || [ "$action" = "reopened" ] || [ -z "$(field '.before')" ]; }; then
    base_ref="$(field '.pull_request.base.ref')"
    start="$(git merge-base "origin/$base_ref" HEAD)"
    range_is_pr=true
    echo "Whole pull request (base $base_ref)."
  else
    before="$(field '.before')"
    if [ -n "$before" ] && [ "$before" != "$zeros" ] && exists "$before"; then
      start="$before"
      is_ancestor "$before" || { echo "History rewritten since $before (force-push)."; rebuild=true; }
      echo "Changes since $before."
    else
      echo "New branch: commits that exist on no other branch."
    fi
  fi
fi

# --- Commits ------------------------------------------------------------------------

others=()
if [ "$range_is_pr" = false ]; then
  while IFS= read -r ref; do
    case "$ref" in
      refs/remotes/origin/HEAD|"refs/remotes/origin/$BRANCH"|refs/remotes/origin/bot-suggest/*) ;;
      *) others+=("$ref") ;;
    esac
  done < <(git for-each-ref --format='%(refname)' refs/remotes/origin)
fi

if [ -n "$start" ]; then range=("$start..HEAD"); else range=("HEAD"); fi
git rev-list --no-merges "${range[@]}" ${others[@]:+--not "${others[@]}"} > all_commits.txt

# The bots' own commits (bot-authors.yml: the shared file with the
# project's own config/bot-authors.yml merged over it, as
# read_config_yaml() does in R; yq is on GitHub's Ubuntu runners).
bot_files=("$BOT_CONFIG")
if [ -f config/bot-authors.yml ] && [ "$BOT_CONFIG" != config/bot-authors.yml ]; then bot_files+=(config/bot-authors.yml); fi
bot_list() { yq eval-all -r ". as \$f ireduce ({}; . * \$f) | (.$1 // [])[]" "${bot_files[@]}"; }
bot_names="$(bot_list bot_names)"
bot_subjects="$(bot_list bot_commit_subjects)"
: > commits.txt
while IFS= read -r c; do
  [ -z "$c" ] && continue
  author="$(git log -1 --format=%an "$c")"
  subject="$(git log -1 --format=%s "$c")"
  if printf '%s\n' "$bot_names" | grep -qxF -- "$author"; then continue; fi
  bot_subject=false
  while IFS= read -r prefix; do
    [ -n "$prefix" ] && case "$subject" in "$prefix"*) bot_subject=true ;; esac
  done <<< "$bot_subjects"
  [ "$bot_subject" = true ] && continue
  # Already reviewed in a pull request run: between that PR's base and the
  # commit its review reached.
  reviewed_in_pr=false
  while read -r pr_base pr_head; do
    [ -z "$pr_head" ] && continue
    if is_ancestor_of "$c" "$pr_head" && ! is_ancestor_of "$c" "$pr_base"; then reviewed_in_pr=true; break; fi
  done < history_pr.txt
  [ "$reviewed_in_pr" = true ] && continue
  echo "$c" >> commits.txt
done < all_commits.txt
rm -f all_commits.txt history_pr.txt

# --- Files ----------------------------------------------------------------------------

: > files_to_check.txt
if [ -n "$FILE_PATTERN" ]; then
  while IFS= read -r c; do
    git diff-tree --no-commit-id --name-only -r "$c" -- "$FILE_PATTERN"
  done < commits.txt | sort -u | while IFS= read -r f; do
    if [ -f "$f" ]; then echo "$f"; fi  # a deleted file: skipped (an && would end the script under pipefail)
  done > files_to_check.txt
  # Files whose Claude call failed in an earlier run ("retry" lines next to
  # the marker, written by commit-updated-files): checked again, also when
  # there are no new commits.
  printf '%s' "$body" | { grep -oE 'bot-suggest: retry [^ ]+' || true; } | awk '{print $NF}' | sort -u | while IFS= read -r f; do
    if [ -f "$f" ]; then
      echo "Checking again (its Claude call failed last time): $f" >&2
      echo "$f"
    fi
  done >> files_to_check.txt
  # The same for a scheduled or manual run: files whose call failed in the
  # last review it continues from (its "Suggestion not made" warnings).
  if [ "$from_history" = true ]; then
    while IFS= read -r f; do
      if [ -n "$f" ] && [ -f "$f" ]; then
        echo "Checking again (its Claude call failed in the last review): $f" >&2
        echo "$f"
      fi
    done < history_failed.txt >> files_to_check.txt
  fi
  sort -u -o files_to_check.txt files_to_check.txt
  count="$(wc -l < files_to_check.txt | tr -d ' ')"
else
  count="$(wc -l < commits.txt | tr -d ' ')"
fi

# Base for the test workflow's history evidence: the starting point, or for
# a new branch the parent of its oldest new commit.
base_rev="$start"
if [ -z "$base_rev" ] && [ -s commits.txt ]; then
  base_rev="$(git rev-parse "$(tail -1 commits.txt)^" 2>/dev/null || true)"
fi

echo "$(wc -l < commits.txt | tr -d ' ') new commit(s), $( [ -n "$FILE_PATTERN" ] && echo "$count file(s) to check" || echo "no file filter" )."
out count "$count"
out base_rev "$base_rev"
out rebuild "$rebuild"
out reviewed_sha "$head"
rm -f history_failed.txt
