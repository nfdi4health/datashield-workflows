# A job's `if:` in words, as "only if: …" (the job runs only then) or
# "skipped: …" (it doesn't run then), for the common patterns: "only if:
# scheduled run", "only if: PR comes from dev", "skipped: PRs from
# bot-suggest/ branches". Anything else as "only if: <expression>". Never
# cut short — labels are wrapped instead (mermaid_label()). `cond` is
# without ${{ }}.
describe_condition <- function(cond) {
  q <- "'([^']*)'"
  head <- "(?:github\\.head_ref|github\\.event\\.pull_request\\.head\\.ref)"
  base <- "(?:github\\.base_ref|github\\.event\\.pull_request\\.base\\.ref)"
  patterns <- list(
    list(sprintf("^github\\.event_name\\s*==\\s*%s$", q), function(x) paste("only if:", event_noun(x))),
    list(sprintf("^github\\.event_name\\s*!=\\s*%s$", q), function(x) paste("skipped:", event_noun(x))),
    list(sprintf("^%s\\s*==\\s*%s$", head, q), function(x) sprintf("only if: PR comes from %s", x)),
    list(sprintf("^%s\\s*!=\\s*%s$", head, q), function(x) sprintf("skipped: PR comes from %s", x)),
    list(sprintf("^%s\\s*==\\s*%s$", base, q), function(x) sprintf("only if: PR into %s", x)),
    list(sprintf("^github\\.ref_name\\s*==\\s*%s$", q), function(x) sprintf("only if: branch %s", x)),
    list(sprintf("^!\\s*startsWith\\(%s,\\s*%s\\)$", head, q), function(x) sprintf("skipped: PRs from %s branches", x)),
    list(sprintf("^startsWith\\(%s,\\s*%s\\)$", head, q), function(x) sprintf("only if: PR from %s branches", x)),
    list("^github\\.event\\.pull_request\\.merged(?:\\s*==\\s*true)?$", function(x) "only if: PR was merged")
  )
  for (p in patterns) {
    m <- regmatches(cond, regexec(p[[1]], cond, perl = TRUE))[[1]]
    if (length(m) >= 1) {
      # The pattern's captured value, if it has one.
      captured <- NULL
      if (length(m) >= 2) {
        captured <- m[2]
      }
      return(p[[2]](captured))
    }
  }
  paste("only if:", cond)
}
