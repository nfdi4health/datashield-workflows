# Sends one Messages API request for call_claude_tool() (`claude`: the
# client, claude_client()) and returns the
# parsed response body. Temporary failures are retried (req_retry()), an
# expired access token is renewed once (refresh_anthropic_token()), and
# every response's token usage is logged (log_claude_usage()). Stops with
# a clear error on a rejected request (logging the tool definition, never
# the prompt), on a response cut off at max_tokens, and on a refusal.
# `forced`: tool_choice names the tool; otherwise "auto".
send_claude_request <- function(claude, tool, messages, forced, renewed = FALSE) {
  config <- claude$config
  if (forced) {
    tool_choice <- list(type = config$tool_choice_type, name = config$tool_name)
  } else {
    tool_choice <- list(type = "auto")
  }
  body <- list(
    model = config$model,
    max_tokens = config$max_tokens,
    thinking = config$thinking,
    tools = list(tool),
    tool_choice = tool_choice,
    messages = messages
  )
  if (!is.null(config$effort)) {
    body$output_config <- list(effort = config$effort)
  }
  if (!is.null(config$fallbacks)) {
    body$fallbacks <- config$fallbacks
  }

  req <- request("https://api.anthropic.com/v1/messages") |>
    req_headers(
      "Authorization" = paste("Bearer", claude$auth$api_key),
      "anthropic-version" = config$api_version,
      "content-type" = "application/json"
    ) |>
    req_body_json(body) |>
    req_timeout(900) |>
    req_error(is_error = function(resp) FALSE) |>  # handle errors manually so we can see the real body
    # Temporary failures are retried within the run: rate limit (429),
    # server errors (5xx), overloaded (529), and connection failures.
    # httr2's back-off (exponential, at most 60 s) honours Retry-After.
    req_retry(max_tries = 4,
              retry_on_failure = TRUE,
              is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503, 504, 529))
  if (!is.null(config$betas)) {
    req <- req_headers(req, "anthropic-beta" = paste(unlist(config$betas), collapse = ","))
  }

  resp <- req_perform(req)

  # The access token lives shorter than a long run: renew it once
  # (refresh_anthropic_token()) and repeat the call with the new one.
  if (resp_status(resp) == 401 && !renewed && grepl("expired", resp_body_string(resp), ignore.case = TRUE)) {
    token <- refresh_anthropic_token()
    if (!is.null(token)) {
      claude$auth$api_key <- token  # shared: every client of the run uses it
      return(send_claude_request(claude, tool, messages, forced, renewed = TRUE))
    }
  }

  if (resp_status(resp) >= 400) {
    # A rejected request (e.g. "JSON schema is invalid") is only explainable
    # with what was sent: log the tool definition, serialized as
    # req_body_json() sends it. Never the prompt — it can hold package code.
    if (resp_status(resp) == 400) {
      message("Tool definition sent with the rejected request:\n",
              jsonlite::toJSON(tool, auto_unbox = TRUE, digits = 22, null = "null", pretty = TRUE))
    }
    stop(sprintf(
      "Anthropic API error (HTTP %d): %s",
      resp_status(resp), resp_body_string(resp)
    ))
  }

  body <- resp_body_json(resp)
  log_claude_usage(config, body$usage)

  if (identical(body$stop_reason, "max_tokens")) {
    stop(sprintf("Claude's response was cut off at max_tokens (%s) — raise max_tokens for this profile in config/claude.yml.", config$max_tokens))
  }
  if (identical(body$stop_reason, "refusal")) {
    category <- body$stop_details$category %||% "unknown"
    stop(sprintf("Claude declined the request (refusal, category: %s).", category))
  }
  body
}
