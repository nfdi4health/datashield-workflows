#!/usr/bin/env bash
# Commits the files in $MANIFEST (relative to $DIRECTORY) on top of the
# checked-out commit, force-pushes to $BRANCH of $REPOSITORY and opens a
# PR into $BASE — or updates the description of the one already open.
# Called by action.yml, which sets all variables from its inputs. Force is
# safe here: callers fold the branch's previous content (e.g. a person's
# edits in the open PR) into what they write.
set -eo pipefail

# actions/checkout's stored GITHUB_TOKEN header would win over the token in
# the remote URL (see commit-updated-files.sh); an empty value resets it.
git_with_token() { git -c "http.https://github.com/.extraheader=" "$@"; }

BODY_FILE="$(realpath "$BODY_FILE")"
MANIFEST="$(realpath "$MANIFEST")"
cd "$DIRECTORY"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${REPOSITORY}.git"

git checkout -B "$BRANCH"
while IFS= read -r f; do
  [ -n "$f" ] && git add -- "$f"
done < "$MANIFEST"

if git diff --cached --quiet; then
  echo "No actual changes — nothing to propose."
  exit 0
fi
git commit -F - <<< "$COMMIT_MESSAGE"
git_with_token push --force origin "HEAD:refs/heads/$BRANCH"

pr=$(gh pr list --repo "$REPOSITORY" --head "$BRANCH" --state open --json url --jq '.[0].url // empty')
if [ -n "$pr" ]; then
  gh pr edit "$pr" --repo "$REPOSITORY" --title "$TITLE" --body-file "$BODY_FILE"
else
  pr=$(gh pr create --repo "$REPOSITORY" --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE")
fi
echo "PR: $pr"
echo "pr_url=$pr" >> "$GITHUB_OUTPUT"
