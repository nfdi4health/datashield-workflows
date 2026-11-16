#!/usr/bin/env bash
# Run by the agent inside Claude Code's sandbox (sandbox-probe.yml), with the
# implementer's sandbox settings. It only writes what it finds into .probe/;
# the workflow judges the files afterwards, outside the sandbox. Names of
# variables are written, never their values.
out=.probe

reach() {  # name url
  local code
  code=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "$2" 2> "$out/$1.err")
  echo "$?" > "$out/$1.exit"
  echo "${code:-000}" > "$out/$1.code"
}
reach unlisted https://example.com
reach allowed https://cloud.r-project.org

# Secrets the runner or the workflow could hold: set (non-empty) ones only.
for v in GITHUB_TOKEN GH_TOKEN ACTIONS_RUNTIME_TOKEN ACTIONS_ID_TOKEN_REQUEST_TOKEN \
         CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY APP_PRIVATE_KEY; do
  [ -n "${!v:-}" ] && echo "$v"
done > "$out/secret-names.txt"
# Values shaped like a GitHub or Anthropic token, whatever their name: a count.
env | grep -cE '(ghs_|ghp_|gho_|ghu_|github_pat_|sk-ant-)' > "$out/token-values.txt"
# A stored GitHub credential in the checkout: an auth header, or a token in
# a remote's URL (claude-code-action writes one there).
git config --get-all http.https://github.com/.extraheader | wc -l > "$out/git-header.txt"
git config --get-regexp '^remote\..*\.url$' | grep -cE '://[^/@]+@' > "$out/git-remote-token.txt"
Rscript -e 'cat(R.version.string)' > "$out/r.txt" 2>&1
echo "finished" > "$out/finished"
