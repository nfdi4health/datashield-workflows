# Command-line arguments that keep a Claude Code run in CI to what the
# workflow gives it: no settings files of the checkout or the runner
# (--setting-sources "": no project hooks, plugins or permissions), and
# MCP servers only from --mcp-config, i.e. none (--strict-mcp-config).
# Used instead of --bare, which would do the same but reads no OAuth
# token and no ANTHROPIC_AUTH_TOKEN ("Anthropic auth is strictly
# ANTHROPIC_API_KEY or apiKeyHelper"), so a subscription run ended "Not
# logged in" (DataSHIELD_CONF_DEMO, 2026-11-12). A CLAUDE.md in the working
# directory is still read, as context only.
claude_code_isolation_args <- function() {
  c("--setting-sources", "", "--strict-mcp-config")
}
