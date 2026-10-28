# Reviews the tests of one file's function (`parsed`, from parse_r_file())
# and merges the findings into the bot PR's `state`: the `review_file` of
# review_files() for suggest_tests.R.
#
# Steps: what the user declined stays out until the code changes
# (declined_suggestions()); a function needing DataSHIELD connections
# without any setup and dslite-setup "never" is listed as untested; the
# existing test files are found (find_test_files()) and run for their
# current results; Claude gets the function, its tests, results, history
# evidence and guidance (ask_claude_for_tests()); its decisions on
# existing tests and its new tests are checked (sort_test_decisions(),
# place_new_tests()) and applied per test file, keeping only what passed
# (apply_function_test_changes()); failed new tests are classified once
# per function (classify_failures(), handle_failed_new_test()). A DSLite
# setup generated for the function is kept only with a passing new test.
#
# `ctx`: review_claude, classification_claude, bot_tests
# (materialize_bot_tests()), reviewed_sha, base_rev, datashield, ds_type,
# may_use_dslite, dslite_setup_mode, dslite_datasets, test_role_guidance,
# scheme, category_meanings, test_data, cache_prompt, max_new_tests,
# accept_reasons, code_issue_confidence, issue_confidence, package_name,
# comment_failures (one PR comment per failed generated test).
# Returns list(state, stats, updated, new_kept).
review_test_file <- function(f, parsed, state, ctx) {
  function_name <- parsed$fn_name
  updated <- character(0)
  new_kept <- 0
  finish <- function(run) {
    merged <- merge_test_findings(state, function_name, run, ctx$reviewed_sha)
    list(state = merged$state, stats = merged$stats, updated = updated, new_kept = new_kept)
  }

  # Test files are named after the R file, not the function (R/initMockData.R
  # -> test-initMockData.R, also when the function is initMockdata()), as in
  # the other workflows that pair R files with their tests.
  file_name <- test_file_name(f)
  fingerprint <- code_fingerprint(fn_source(parsed))
  declined <- declined_suggestions(state, function(e) identical(e$fn, function_name), fingerprint, ctx$reviewed_sha)
  state <- declined$state
  declined <- declined$declined
  declined_of <- function(kinds) vapply(Filter(function(e) e$kind %in% kinds, declined), function(e) e$description, character(1))
  run <- list(user_edited = ctx$bot_tests$user_edited, new = list(), changes = list(), notes = list(), bugs = list(), failed = list(), repeats = 0L, code = fingerprint)

  # Re-checked per function: a DSLite setup generated for an earlier function
  # in this run is reused by later ones.
  uses_connections <- uses_ds_connections(parsed)
  needs_dslite <- ctx$may_use_dslite && (identical(ctx$ds_type, "client") || uses_connections)
  setup_plan <- if (needs_dslite) {
    decide_dslite_setup(ctx$dslite_setup_mode, detect_connection_approaches())
  } else {
    "not_needed"
  }
  if (identical(setup_plan, "none")) {
    message(sprintf("%s: needs DataSHIELD connections, but the tests have none and dslite-setup is 'never' — not tested.", function_name))
    return(finish(c(run, list(untested = f))))
  }

  test_files <- find_test_files(file_name, ctx$scheme)
  paths <- vapply(test_files, function(t) t$path, character(1))
  names(test_files) <- paths
  blocks <- lapply(test_files, function(t) parse_test_file(t$content))
  baseline <- lapply(test_files, function(t) run_tests_quietly(t$path, ctx$package_name, sprintf("existing tests in %s", t$path)))
  run$current <- unlist(lapply(paths, function(p) lapply(baseline[[p]], function(r) list(file = p, description = r$description, passed = isTRUE(r$passed)))), recursive = FALSE)
  earlier <- Filter(function(e) identical(e$fn, function_name) && identical(e$status, "active") && e$kind %in% c("note", "bug", "failed"), state$entries)

  offered_datasets <- if (identical(setup_plan, "create")) {
    ctx$dslite_datasets
  } else {
    NULL
  }
  support_files <- test_support_files()
  categories <- NULL
  if (ctx$scheme$categorised) {
    categories <- ctx$scheme$categories
  }
  # Without test files of its own, the function gets examples of others.
  examples <- list()
  if (length(test_files) == 0) {
    examples <- example_test_files(ctx$scheme)
  }
  context <- list(
    role_text = build_test_role_guidance(ctx$datashield, ctx$ds_type, identical(setup_plan, "reuse"), offered_datasets, ctx$test_role_guidance, uses_connections),
    scheme_text = format_test_scheme_guidance(ctx$scheme, ctx$category_meanings, file_name, test_files),
    categories = categories,
    test_files = test_files,
    examples = examples,
    support_files = c(support_files, test_sourced_files(support_files)),
    test_data = ctx$test_data,
    test_results = format_test_results(baseline),
    evidence = build_test_evidence(f, paths, ctx$base_rev),
    dslite_datasets = offered_datasets,
    dataset_choices = ctx$dslite_datasets,  # the run's, for a tool schema that is the same for every function
    cache_prompt = ctx$cache_prompt,
    max_new_tests = ctx$max_new_tests,
    earlier = earlier
  )

  result <- try_claude_call(function() ask_claude_for_tests(ctx$review_claude, parsed, context), f, paste0(function_name, "()"))
  if (is.null(result)) {
    return(finish(run))
  }
  run$decisions <- result$earlier_findings

  # Decisions on existing tests, per test file; declined ones stay out.
  sorted <- sort_test_decisions(result$existing_tests, paths, blocks, baseline, declined_of("updated"), declined_of("deleted"), ctx$code_issue_confidence, function_name)
  run$notes <- c(run$notes, sorted$notes)
  run$bugs <- c(run$bugs, sorted$bugs)

  # New tests, each into its file; declined ones stay out.
  placed <- place_new_tests(result, test_files, blocks, declined_of("new"), ctx$scheme, file_name, ctx$accept_reasons, function_name)

  changed_paths <- unique(c(
    names(placed$by_file),
    Filter(function(p) length(sorted$reviews[[p]]$updates) + length(sorted$reviews[[p]]$deletes) > 0, paths)
  ))
  if (length(changed_paths) == 0) {
    message(sprintf("%s: nothing to change.", function_name))
    return(finish(run))
  }

  created_setup <- NULL
  if (length(placed$by_file) > 0 && !is.null(offered_datasets) && isTRUE(nzchar(result$dslite_dataset))) {
    dataset_choice <- Find(function(d) identical(d$name, result$dslite_dataset), offered_datasets)
    if (is.null(dataset_choice)) {
      message(sprintf(
        "%s: Claude returned dslite_dataset '%s', which isn't one of the offered options — skipping DSLite setup.",
        function_name, result$dslite_dataset
      ))
    } else {
      created_setup <- ensure_dslite_setup_file(dataset_choice, ctx$package_name)
    }
  }

  applied <- apply_function_test_changes(changed_paths, list(
    test_files = test_files, blocks = blocks, reviews = sorted$reviews,
    new_tests = placed$tests, targets = placed$targets, new_by_file = placed$by_file,
    result = result, earlier = earlier, scheme = ctx$scheme
  ), run, function_name, ctx$package_name)
  run <- applied$run
  updated <- applied$updated
  new_kept <- applied$kept_new

  # All of the function's failed new tests classified at once (R where the
  # message decides, else one Claude call); real bugs reported, others
  # commented or listed (handle_failed_new_test()). Real bugs at an issue
  # confidence go into the function's issue together, one post per run.
  failures <- applied$failures
  if (length(failures) > 0) {
    verdicts <- classify_failures(ctx$classification_claude, failures, fn_source(parsed), function_name)
    findings <- list()
    issue_bugs <- integer(0)
    for (k in seq_along(failures)) {
      outcome <- handle_failed_new_test(failures[[k]]$fail, failures[[k]]$block, failures[[k]]$path, verdicts[[k]],
                                        function_name, ctx$code_issue_confidence, ctx$issue_confidence, ctx$comment_failures)
      if (is.null(outcome)) {
        next
      }
      if (outcome$kind == "bug") {
        run$bugs[[length(run$bugs) + 1]] <- outcome$entry
        if (!is.null(outcome$issue_finding)) {
          findings[[length(findings) + 1]] <- outcome$issue_finding
          issue_bugs <- c(issue_bugs, length(run$bugs))
        }
      }
      if (outcome$kind == "failed") {
        run$failed[[length(run$failed) + 1]] <- outcome$entry
      }
    }
    if (length(findings) > 0) {
      issue <- create_bug_issue(function_name, findings) %||% ""
      for (b in issue_bugs) {
        run$bugs[[b]]$issue <- issue
      }
    }
  }

  # A freshly generated DSLite setup is only kept alongside at least one
  # passing new test.
  if (!is.null(created_setup)) {
    if (new_kept > 0) {
      updated <- c(updated, created_setup)
      run$setups <- created_setup
    } else {
      file.remove(created_setup)
    }
  }
  finish(run)
}
