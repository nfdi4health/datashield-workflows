# The environment variables a child R process running package or
# generated code must not get: the Claude and GitHub tokens, and what new
# ones could be requested with (refresh_anthropic_token()'s IDs, GitHub's
# OIDC request). Callers blank them for the child: callr's `env` (names ->
# "") or system2()'s `env` ("NAME=" entries). Deliberately not a setting,
# so no repository override can hand credentials to generated code.
credential_variables <- function() {
  c("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN", "GH_TOKEN", "GITHUB_TOKEN",
    "ANTHROPIC_ORG_ID", "ANTHROPIC_SERVICE_ACCOUNT_ID", "ANTHROPIC_FEDERATION_RULE_ID",
    "ACTIONS_ID_TOKEN_REQUEST_URL", "ACTIONS_ID_TOKEN_REQUEST_TOKEN")
}
