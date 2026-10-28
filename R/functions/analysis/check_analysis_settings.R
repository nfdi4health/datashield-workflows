# Checks the merged settings (config/analysis-suggest.yml plus a project's
# own file) before anything runs, and stops with every problem at once. A
# project's override is merged key by key, so a typo there (a negative
# number, an unknown kind, a broken pattern) would otherwise surface
# later as an unclear error. Messages are for whoever edits the settings,
# so they name the setting's path in the file.
check_analysis_settings <- function(settings) {
  problems <- character(0)
  need <- function(ok, what) {
    if (!isTRUE(ok)) {
      problems <<- c(problems, what)
    }
  }
  number <- function(x) is.numeric(x) && length(x) == 1 && !is.na(x)
  text <- function(x) is.character(x) && length(x) == 1 && nzchar(x)

  m <- settings$mock_data
  need(number(m$rows_per_study) && m$rows_per_study >= 1, "mock_data.rows_per_study must be a number of at least 1")
  need(number(m$missing_share) && m$missing_share >= 0 && m$missing_share < 1, "mock_data.missing_share must be at least 0 and below 1")
  need(number(m$seed), "mock_data.seed must be a number")
  need(number(m$decimals) && m$decimals >= 0, "mock_data.decimals must be 0 or more")
  need(text(m$folder), "mock_data.folder must be a folder name")
  need(number(settings$max_script_lines) && settings$max_script_lines >= 20, "max_script_lines must be at least 20 (the header alone takes several lines)")
  need(number(settings$max_file_title_chars) && settings$max_file_title_chars >= 5, "max_file_title_chars must be at least 5")
  n <- settings$numbering
  need(number(n$first) && n$first >= 1 && number(n$reserved_from) && n$reserved_from > n$first, "numbering.first must be at least 1 and below numbering.reserved_from")
  need(number(settings$repair_rounds) && settings$repair_rounds >= 0, "repair_rounds must be 0 or more")
  need(number(settings$test_run_timeout_seconds) && settings$test_run_timeout_seconds > 0, "test_run_timeout_seconds must be above 0")

  for (key in c("scripts", "main", "dependencies", "project_config", "mock_data", "login_production", "login_testing")) {
    need(text(settings$paths[[key]]), sprintf("paths.%s must be a path", key))
  }
  need(text(settings$profiles$production) && text(settings$profiles$testing), "profiles.production and profiles.testing must be profile names")
  mk <- settings$markers
  need(all(vapply(mk[c("main_start", "main_end", "dependencies_start", "dependencies_end", "dslite_mock_data")], text, logical(1))),
    "markers.* must each be one line of text")
  need(!identical(mk$main_start, mk$main_end) && !identical(mk$dependencies_start, mk$dependencies_end), "each block's start and end marker must differ")

  kinds <- unlist(settings$variable_types)
  need(length(kinds) > 0 && all(kinds %in% c("continuous", "integer", "categorical")),
    "variable_types must map type names to continuous, integer or categorical")
  need(text(settings$package_catalogue), "package_catalogue must be a URL")
  need(text(settings$function_catalogue), "function_catalogue must be a URL")
  statuses <- unlist(settings$package_status)
  need(length(statuses) > 0 && all(statuses %in% package_statuses()),
    sprintf("package_status must list some of: %s", paste(package_statuses(), collapse = ", ")))
  need(text(settings$client_suffix), "client_suffix must be text, e.g. Client")
  need(is.null(settings$excluded_functions) || (is.list(settings$excluded_functions) && !is.null(names(settings$excluded_functions)) && all(vapply(settings$excluded_functions, function(r) is.null(r) || (is.character(r) && length(r) == 1), logical(1)))),
    "excluded_functions must map each function name to the reason Claude is told, e.g. ds.glmSLMA: not available in the test environment")
  need(text(settings$credential_pattern) && !inherits(tryCatch(suppressWarnings(grepl(settings$credential_pattern, "")), error = identity), "error"),
    "credential_pattern must be a valid regular expression")
  need(text(settings$gap_issue_repo) && grepl("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", settings$gap_issue_repo), "gap_issue_repo must be owner/repo")
  need(number(settings$gap_issues_max) && settings$gap_issues_max >= 0, "gap_issues_max must be 0 or more")

  if (length(problems) > 0) {
    stop(paste(c("config/analysis-suggest.yml (with the project's own settings merged in) has problems:", paste("-", problems)), collapse = "\n"), call. = FALSE)
  }
  invisible(settings)
}
