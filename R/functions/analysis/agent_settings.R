# Claude Code settings for the analysis agent (written to a file and passed
# with --settings). The sandbox runs every shell command with no network
# and no access to the project's real login file or .Renviron (the
# dsAnalysis README promises those never reach Claude); the same paths are
# denied to the Read tool. Mock data stays readable: the test setup loads
# it, and the agent sees it only through DataSHIELD calls in its try runs.
# Commands may write only to `.agent/` (the agent's drafts) and `results/`
# (the outputs a draft writes), so code the agent tries can't change the
# project's other files. `deny_paths` are relative to the project root.
agent_settings <- function(deny_paths, writable = c(".agent", "results")) {
  deny_paths <- unique(deny_paths[nzchar(deny_paths)])
  list(
    permissions = list(
      deny = as.list(c(sprintf("Read(./%s)", deny_paths), sprintf("Edit(./%s)", deny_paths)))
    ),
    sandbox = list(
      enabled = TRUE,
      failIfUnavailable = TRUE,
      allowUnsandboxedCommands = FALSE,
      network = list(allowedDomains = list()),
      filesystem = list(
        denyRead = as.list(normalizePath(deny_paths, mustWork = FALSE)),
        denyWrite = list(normalizePath(".", mustWork = FALSE)),
        allowWrite = as.list(normalizePath(writable, mustWork = FALSE))
      )
    )
  )
}
