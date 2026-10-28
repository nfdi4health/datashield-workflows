#!/usr/bin/env bash
# Copies this repository, as the runner fetched it for this action (at the
# commit the calling workflow runs), into TARGET. The repository root is
# three levels above this action's folder (.github/actions/shared-files).
# Writes `sha` to GITHUB_OUTPUT: the runner keeps actions in a folder named
# after their ref, which for `$/` is the commit; empty if it isn't one.
set -euo pipefail

root="$(cd "$GITHUB_ACTION_PATH/../../.." && pwd)"
case "$TARGET" in
  ""|"."|"./"|/*|*..*)
    echo "::error::shared-files: path must be a folder inside the workspace, not '$TARGET'."
    exit 1
    ;;
esac

rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -R "$root/." "$TARGET/"

sha="$(basename "$root")"
if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  sha=""
fi
echo "sha=$sha" >> "$GITHUB_OUTPUT"
echo "Shared files from ${sha:-an unnamed ref} in $TARGET."
