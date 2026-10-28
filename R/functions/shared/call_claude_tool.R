# Shared low-level Claude tool-call mechanics: builds the request, has
# Claude answer through the given tool, and returns its parsed input. Every
# Claude-calling function shares this; only the client (claude_client():
# profile settings and access token), tool schema, and prompt differ per
# caller. The tool's name is set here from
# config$tool_name — the same value tool_choice names — so the two can
# never disagree; tool schema builders deliberately leave `name` out.
#
# Optional per profile in config/claude.yml: `effort` (sent as
# output_config.effort), `fallbacks` + `betas` (server-side fallback to
# another model when the request is refused), and `cache_ttl` ("5m" or
# "1h", for prompts split by split_cached_prompt()).
#
# Every tool is sent with `strict: true` (strict_tool_schema(): the
# arguments always match the schema; unsupported limits such as maxItems
# are checked in R instead), unless a profile sets `strict: false`.
# `tool_choice_type`: "tool" forces the call (Claude Opus 5, Sonnet 5).
# Newer models (Claude Opus 5.5, Sonnet 5.5, Fable 5.1) reject forced
# calls with a 400; for them set "auto": the prompt then ends with an
# instruction to answer through the tool, and if Claude still answers in
# text it is asked once more in the same conversation (appended, never
# edited). Those models also can't run with thinking disabled — their
# profiles need `thinking: {type: adaptive}`.
#
# `prompt` is a string, or list(cached, rest): the shared part then goes
# first with a cache marker, so the next call of the run with the same
# shared part (and the same tool definition, which comes before it) reads
# it from the prompt cache. Every call logs its token usage — the
# measurement channel for what a run costs (dev-notes/claude-costs.md).
call_claude_tool <- function(claude, tool, prompt) {
  config <- claude$config
  tool$name <- config$tool_name
  forced <- !identical(config$tool_choice_type, "auto")
  if (!isFALSE(config$strict)) {
    strict <- strict_tool_schema(tool$input_schema)
    if (strict$ok) {
      tool$input_schema <- strict$schema
      tool$strict <- TRUE
    } else {
      message(sprintf("Tool %s has a free-form object, sent without strict: true.", tool$name))
    }
  }

  content <- if (is.list(prompt)) {
    marker <- list(type = "ephemeral")
    if (identical(config$cache_ttl, "1h")) {
      marker$ttl <- "1h"
    }
    list(
      list(type = "text", text = prompt$cached, cache_control = marker),
      list(type = "text", text = prompt$rest)
    )
  } else {
    list(list(type = "text", text = prompt))
  }
  if (!forced) {
    content[[length(content) + 1]] <- list(type = "text", text = sprintf(
      "Give your answer only by calling the %s tool, not as text.", config$tool_name))
  }
  messages <- list(list(role = "user", content = content))

  body <- send_claude_request(claude, tool, messages, forced)
  tool_block <- Filter(function(block) identical(block$type, "tool_use"), body$content)

  # Without a forced call Claude may answer in text: ask once more, in the
  # same conversation (its answer appended unchanged, thinking included).
  if (length(tool_block) == 0 && !forced) {
    message(sprintf("Claude answered without calling %s; asking again.", config$tool_name))
    messages <- c(messages, list(
      list(role = "assistant", content = body$content),
      list(role = "user", content = list(list(type = "text", text = sprintf(
        "Call the %s tool now with your answer.", config$tool_name))))
    ))
    body <- send_claude_request(claude, tool, messages, forced)
    tool_block <- Filter(function(block) identical(block$type, "tool_use"), body$content)
  }

  if (length(tool_block) == 0) {
    stop(sprintf(
      "No tool_use content block in Claude's response. Full response: %s",
      jsonlite::toJSON(body, auto_unbox = TRUE)
    ))
  }

  tool_block[[1]]$input
}
