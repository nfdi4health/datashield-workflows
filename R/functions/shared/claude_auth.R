# The Anthropic access token of a run, held in one place (an environment)
# so that every Claude client of the run (claude_client()) sees a token
# renewed during the run (send_claude_request(), refresh_anthropic_token()).
claude_auth <- function(api_key = Sys.getenv("ANTHROPIC_API_KEY")) {
  auth <- new.env(parent = emptyenv())
  auth$api_key <- api_key
  auth
}
