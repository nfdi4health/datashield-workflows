#!/usr/bin/env bash
# A fresh installation token of the bots' App for the hub ($HUB) only,
# with Contents: write, printed to stdout. An App token lasts one hour, a
# literature watch run up to five and a half (run 44202459011 lost its
# vocabulary and report pushes to an expired token), so read-loop.sh asks
# for a new one before the old one runs out. Signs the App's JWT with
# $APP_PRIVATE_KEY (iss = $APP_CLIENT_ID, which GitHub accepts in place of
# the App ID); the key goes to a private temporary file, removed at once.
# $GITHUB_API_URL for tests.
set -euo pipefail
api="${GITHUB_API_URL:-https://api.github.com}"
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
key="$(mktemp)"
trap 'rm -f "$key"' EXIT
chmod 600 "$key"
printf '%s\n' "$APP_PRIVATE_KEY" > "$key"
now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 540)) "$APP_CLIENT_ID" | b64)
signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$key" | b64)
jwt="$header.$payload.$signature"
rm -f "$key"
installation=$(curl -sSf -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "$api/repos/$HUB/installation" | jq -r '.id')
jq -n --arg repo "${HUB#*/}" '{repositories: [$repo], permissions: {contents: "write"}}' |
  curl -sSf -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
    "$api/app/installations/$installation/access_tokens" --data @- | jq -er '.token'
