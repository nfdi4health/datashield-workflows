# Splits a filled prompt at the line "<!-- per function -->" into the part
# shared by every call of a run (instructions, the package's test
# material) and the part that differs per call. call_claude_tool() sends
# the shared part with a cache marker, so later calls in the run read it
# from the prompt cache instead of paying for it again. A prompt without
# the marker (e.g. a repository's own older copy) is returned as is and
# sent uncached.
split_cached_prompt <- function(prompt, marker = "<!-- per function -->") {
  at <- regexpr(marker, prompt, fixed = TRUE)
  if (at < 0) {
    return(prompt)
  }
  list(
    cached = trimws(substr(prompt, 1, at - 1)),
    rest = trimws(substr(prompt, at + attr(at, "match.length"), nchar(prompt)))
  )
}
