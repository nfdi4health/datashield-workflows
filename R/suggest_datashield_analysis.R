#!/usr/bin/env Rscript
# Drafts DataSHIELD analysis scripts from the analyst's plan file
# (config/analysis-plan.yml in a dsAnalysis project) and tests them before
# anything is proposed:
#   1. read and check the plan's core (studies, variables, steps);
#   2. decide per step: new, changed (untouched files, plan changed),
#      unchanged, or edited by the analyst (never overwritten);
#   3. install the studies' server packages and matching clients;
#   4. write mock data from the plan and point the project's DSLite setup
#      at it (dsAnalysis's own functions);
#   5. one step at a time, in plan order: ask Claude for it, check every
#      DataSHIELD call and column against the installed clients and the
#      plan, run all scripts in testing mode, repair rounds if it fails;
#      steps depending on a failed one (depends_on, else all earlier
#      steps) wait for the next run;
#   6. keep the passing scripts, write the main.R and dependencies.R
#      blocks, the report, and updated_files.txt for the suggestion PR.
# Settings: config/analysis-suggest.yml; wording: config/analysis-texts.yml
# (both overridable per project). Design: dev-notes/analysis-suggest.md.
# Logic lives in R/functions/shared/ and R/functions/analysis/, one
# function per file.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/analysis")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "analysis")), pattern = "\\.R$", full.names = TRUE), source)

# The Claude client (profile "datashield-analysis" of config/claude.yml);
# the prompt templates are in the context below.
analysis_claude <- claude_client("datashield-analysis")
# Project files at the same paths are merged over the shared defaults.
settings <- check_analysis_settings(read_config_yaml("config/analysis-suggest.yml"))
texts <- read_config_yaml("config/analysis-texts.yml")

gh_token       <- Sys.getenv("GH_TOKEN")  # read-only here: open gap issues of the collection repo
plan_file      <- Sys.getenv("PLAN_FILE", "config/analysis-plan.yml")
dsanalysis_dir <- Sys.getenv("DSANALYSIS_DIR", ".dsanalysis")
summary_file   <- Sys.getenv("GITHUB_STEP_SUMMARY")
paths          <- settings$paths
# File and profile names the texts mention ({{MAIN}} etc. in analysis-texts.yml).
names_in_texts <- list(MAIN = paths$main, DEPENDENCIES = paths$dependencies,
  TESTING = settings$profiles$testing, PRODUCTION = settings$profiles$production)

write_outputs <- function(report, updated) {
  writeLines(updated, "updated_files.txt")
  if (length(report) > 0) {
    writeLines(report, "suggestion_report.md")
    if (nzchar(summary_file)) {
      write(report, summary_file, append = TRUE)
    }
    message(paste(report, collapse = "\n"))
  }
}

# --- 1. The plan -----------------------------------------------------------------

plan <- tryCatch(read_analysis_plan(plan_file, settings$variable_types, texts), error = function(e) {
  msg <- conditionMessage(e)
  if (nzchar(summary_file)) {
    write(c(texts$report$plan_errors_heading, "", "```", msg, "```"), summary_file, append = TRUE)
  }
  stop(msg, call. = FALSE)
})
plan_text <- paste(readLines(plan_file, warn = FALSE), collapse = "\n")

# --- 2. What to write --------------------------------------------------------------

existing <- find_bot_step_files(paths$scripts)
classified <- classify_plan_steps(plan, existing, texts, names_in_texts)
steps <- classified$steps
to_write <- classified$to_write
if (length(to_write) == 0) {
  write_outputs(texts$report$nothing_to_do, character(0))
  quit(save = "no")
}

# --- 3. Packages -------------------------------------------------------------------

usable <- usable_server_packages(plan, texts)
catalogue <- read_package_catalogue(plan$`package-catalogue` %||% settings$package_catalogue)
functions <- read_function_catalogue(settings$function_catalogue)
# Which catalogue packages may be suggested: the plan's package-status, else the settings'.
statuses <- unlist(plan$`package-status` %||% settings$package_status)
installed <- install_study_packages(usable$packages, catalogue, settings$client_suffix, texts)
notes <- c(usable$notes, installed$notes)
if ("retired" %in% statuses) {
  notes <- c(notes, texts$notes$retired_included)
}
if (length(installed$clients) == 0) {
  stop("No client package could be installed for the studies' server packages; see the messages above.", call. = FALSE)
}

# --- 4. Mock data, DSLite setup, login file -----------------------------------------

mock <- generate_mock_data(plan, settings$mock_data)
mock_paths <- write_mock_data(mock, file.path(paths$mock_data, settings$mock_data$folder))
login_files <- project_login_files(paths, settings$profiles)
login <- check_login_file(login_files$production, plan, settings$credential_pattern, texts)
notes <- c(notes, login$notes)
setup_file <- update_dslite_setup(login_files$testing, dsanalysis_dir, settings$mock_data$folder, names(mock),
  installed$servers, settings$markers$dslite_mock_data, plan$symbol, login$connections)
if (is.null(setup_file)) {
  stop(sprintf("The project needs the dsAnalysis DSLite setup (%s) for the test run.", login_files$testing), call. = FALSE)
}


# --- 5. Claude, checks and test run ---------------------------------------------------

excluded <- Filter(Negate(is.null), settings$excluded_functions)
reference <- client_function_reference(installed$clients, names(excluded))
catalogue_prompt <- format_catalogue_for_prompt(catalogue, functions, c(installed$servers, installed$clients), settings$client_suffix, statuses)
context <- list(
  connections = login$connections,
  symbol = plan$symbol,
  servers = vapply(plan$studies, function(s) s$server, character(1)),
  function_reference = reference$text,
  excluded_functions = format_excluded_functions(excluded),
  catalogue_text = catalogue_prompt$text,
  catalogue_names = catalogue_prompt$names,
  catalogue_functions = catalogue_prompt$functions,
  # The fixed start of the issue title template marks the gap issues.
  gap_issues = fetch_gap_issues(settings$gap_issue_repo, sub("\\{\\{.*$", "", texts$issue$title), settings$gap_issues_max),
  existing_steps = format_existing_steps(sort(existing$path[!existing$step %in% to_write])),
  plan_text = plan_text,
  max_lines = settings$max_script_lines,
  numbers = assign_step_numbers(to_write, existing, paths$scripts, settings$numbering),
  header_values = list(PLAN_FILE = plan_file, TESTED_WITH = installed$tested_with),
  claude = analysis_claude,
  prompt_template = read_text_file("prompts/analysis-script-prompt.md"),
  repair_template = read_text_file("prompts/analysis-repair-prompt.md")
)
checks <- list(
  reference = reference,
  variables = vapply(plan$variables, function(v) v$name, character(1)),
  login_file = login_files$testing
)

# Scripts of steps being rewritten, to restore them if the new version fails.
rewritten <- existing[existing$step %in% to_write, ]
old_content <- setNames(lapply(rewritten$path, readLines, warn = FALSE), rewritten$path)

# One step at a time, in plan order; a step waits while one it depends on
# fails (the plan's depends_on, else all earlier steps). Failed scripts are
# shown in the job log before they are removed.
drafted <- draft_steps_in_order(to_write, plan, steps, existing, context, checks, settings, texts, rewritten, old_content)
notes <- c(notes, drafted$notes)

# --- 6. Results ------------------------------------------------------------------------

settled <- settle_step_results(steps, to_write, drafted, rewritten, old_content, texts)
steps <- verify_note_issues(verify_note_functions(settled$steps, functions, settings$client_suffix), context$gap_issues)
updated <- character(0)
if (length(settled$written_files) > 0) {
  replaced <- setdiff(rewritten$path[!file.exists(rewritten$path)], settled$written_files)
  notes <- c(notes, update_project_blocks(steps, installed, catalogue, settings, texts))
  updated <- c(settled$written_files, replaced, mock_paths$written, mock_paths$removed, setup_file, paths$main, paths$dependencies)
}

report <- format_analysis_report(list(
  # Unchanged steps, and edited ones whose plan entry didn't change, need no mention.
  steps = Filter(function(s) !s$status %in% c("unchanged", "edited") || !is.null(s$error), steps),
  notes = unique(notes), tested_with = installed$tested_with, gap_issue_repo = settings$gap_issue_repo,
  names = names_in_texts,
  package_status = lapply(catalogue, function(p) p$status),
  gap_issues = context$gap_issues
), texts)
write_outputs(report, updated)
