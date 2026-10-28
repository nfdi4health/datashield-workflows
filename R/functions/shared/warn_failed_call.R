# Makes a failed Claude call visible: a GitHub Actions warning annotation
# on the run's summary page and in the pull request's checks (the job
# stays green), on top of the log message. Temporary failures are already
# retried within the run (call_claude_tool()), so what arrives here either
# kept failing or is persistent (a rejected request, a refusal, an answer
# cut off at max_tokens) and needs attention. `label` names what failed
# (a function or file), `file` is its path in the caller repository.
warn_failed_call <- function(label, file, error) {
  # Workflow command escaping: % and line breaks everywhere, and in the
  # properties (file=, title=) also : and ,.
  escape <- function(x) gsub("\n", "%0A", gsub("\r", "%0D", gsub("%", "%25", x, fixed = TRUE), fixed = TRUE), fixed = TRUE)
  escape_property <- function(x) gsub(",", "%2C", gsub(":", "%3A", escape(x), fixed = TRUE), fixed = TRUE)
  text <- sprintf("Claude call failed for %s: %s", label, conditionMessage(error))
  if (nchar(text) > 500) {
    text <- paste0(substr(text, 1, 500), " …")
  }
  cat(sprintf("::warning file=%s,title=%s::%s\n",
              escape_property(file), escape_property("Suggestion not made"), escape(text)))
}
