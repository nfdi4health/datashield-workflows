#!/usr/bin/env Rscript
# Writes a high-level overview of the repository's GitHub Actions workflows
# into .github/workflow-graphs/README.md: a table of all workflows and one
# Mermaid diagram per situation (what runs on which event, what those
# workflows start and produce). Deterministic — only the YAML is read,
# including the reusable workflows it calls (resolve_called_workflows()),
# to find the chains that start inside them and their conditions.
#
# Only the marked blocks of the README are replaced (update_marked_blocks());
# text around them is never touched; the calling workflow commits the
# result. Started by a pull request (PR_NUMBER set), it can't commit: it
# only says so in one short comment (comment_once()) and stops.
#
# This file only wires environment inputs together; all logic lives in
# R/functions/shared/ and R/functions/workflow-graphs/ — one function per
# file, loaded in bulk below.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists(".shared-workflows/R/functions")) {
  ".shared-workflows/R/functions"
} else {
  "R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "workflow-graphs")), pattern = "\\.R$", full.names = TRUE), source)

gh_token      <- Sys.getenv("GH_TOKEN")
repo          <- Sys.getenv("GITHUB_REPOSITORY")
pr_number     <- Sys.getenv("PR_NUMBER")  # set only in a pull request
workflows_dir <- Sys.getenv("WORKFLOWS_DIR", ".github/workflows")
# Not in .github/workflows/: GitHub treats every file there as a workflow,
# and pushing one needs the App's Workflows permission.
readme_path   <- Sys.getenv("README_PATH", ".github/workflow-graphs/README.md")

if (nzchar(pr_number)) {
  comment_once(pr_number, paste(
    "**Workflow graphs** can't commit on a pull request, so the diagrams weren't updated here.",
    "Run it on a push to the branch where merges land (e.g. `dev`) or by hand instead —",
    "see the [example caller](https://github.com/nfdi4health/datashield-workflows/blob/main/examples/workflow-graphs.yml)."
  ), "workflow graphs on a pull request")
  quit(save = "no")
}

workflows <- read_workflows(workflows_dir)

called <- resolve_called_workflows(workflows)
unreadable <- Filter(function(c) !isTRUE(c$readable), called)
if (length(unreadable) > 0) {
  # A private repository, or a temporary API problem — either way the
  # diagrams show these calls without their contents and chains.
  message(sprintf("::warning::Could not read %d called workflow(s): %s", length(unreadable),
                  paste(vapply(unreadable, function(c) c$ref$label, character(1)), collapse = ", ")))
}
chains <- workflow_chains(workflows, called)

# What each workflow produces can't be read from the YAML — it's described
# in config/workflow-outcomes.yml (a caller's own copy is merged over it).
outcomes_config <- read_config_yaml("config/workflow-outcomes.yml", required = FALSE)
if (is.null(outcomes_config)) {
  outcomes_config <- list()
}

blocks <- workflow_graph_blocks(workflows, called, chains, outcomes_config)
current <- NULL
cleaned <- NULL
if (file.exists(readme_path)) {
  current <- readLines(readme_path, warn = FALSE)
  cleaned <- drop_old_starter_headings(current)
}
updated <- update_marked_blocks(cleaned, blocks, workflow_readme_starter)
if (!identical(current, updated)) {
  dir.create(dirname(readme_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(updated, readme_path)
}
