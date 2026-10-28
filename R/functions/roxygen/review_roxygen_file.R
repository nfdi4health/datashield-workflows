# Reviews the roxygen block of one file's function (`parsed`, from
# parse_r_file()) and merges the findings into the bot PR's `state`: the
# `review_file` of review_files() for suggest_roxygen.R.
#
# The block reviewed is the one the open bot PR proposes, unless the user
# edited the docs since (review_source_block()). Fields the user declined
# stay as they are until the function's code changes
# (declined_suggestions()). Claude returns fields and reasons; only
# accepted reasons are applied (accepted_roxygen_fields()), R assembles
# the block (build_roxygen_block()) and writes it in place. Possible code
# bugs are kept by confidence whether or not the docs change.
#
# `ctx`: claude (the client), bot_ref, base_rev, reviewed_sha, ds_type,
# role_text and role_text_local (a utility package's functions without
# DataSHIELD connections get the variant without the login example),
# accept_reasons, code_issue_confidence (empty: no possible bugs asked).
# Returns list(state, stats, updated).
review_roxygen_file <- function(f, parsed, state, ctx) {
  source_block <- review_source_block(f, parsed, ctx$bot_ref, ctx$base_rev)
  parsed <- source_block$parsed
  fingerprint <- code_fingerprint(fn_source(parsed))
  declined <- declined_suggestions(state, function(e) identical(e$file, f), fingerprint, ctx$reviewed_sha)
  state <- declined$state
  declined_fields <- vapply(Filter(function(e) identical(e$kind, "applied"), declined$declined), function(e) e$field, character(1))
  earlier <- Filter(function(e) identical(e$file, f) && identical(e$status, "active") && e$kind %in% c("dropped", "bug"), state$entries)
  no_change <- list(state = state, stats = c(new = 0L, crossed = 0L, repeats = 0L), updated = character(0))

  with_code_issues <- length(ctx$code_issue_confidence) > 0
  role_text <- if (identical(ctx$ds_type, "utility") && !uses_ds_connections(parsed)) {
    ctx$role_text_local
  } else {
    ctx$role_text
  }
  result <- try_claude_call(function() {
    ask_claude_for_review(ctx$claude, parsed, select_profile(parsed), role_text, earlier, with_code_issues)
  }, f)
  if (is.null(result)) {
    return(no_change)
  }

  # Code defects are reported whether or not the documentation changes.
  run <- list(applied = list(), dropped = list(), decisions = result$earlier_findings,
              bugs = kept_code_issues(result$code_issues, ctx$code_issue_confidence, f), code = fingerprint)
  if (length(run$bugs) > 0) {
    message(sprintf("%s: %d possible code issue(s) noted.", f, length(run$bugs)))
  }

  updated <- character(0)
  if (!isTRUE(result$needs_changes)) {
    message(sprintf("%s: documentation already adequate, skipping.", f))
  } else {
    review <- accepted_roxygen_fields(result, parsed, ctx$accept_reasons, f)
    for (key in intersect(review$accepted, declined_fields)) {
      message(sprintf("%s: not changing '%s' again — declined.", f, key))
    }
    review$accepted <- setdiff(review$accepted, declined_fields)
    review$applied <- Filter(function(ch) !ch$field %in% declined_fields, review$applied)
    run$dropped <- review$dropped
    new_block <- if (length(review$accepted) == 0) {
      message(sprintf("%s: no change above the threshold, skipping.", f))
      NULL
    } else {
      tryCatch(build_roxygen_block(result, parsed, f, review$accepted), error = function(e) {
        message(sprintf("Failed to assemble roxygen block for %s: %s", f, conditionMessage(e)))
        NULL
      })
    }
    if (!is.null(new_block)) {
      message(sprintf("%s: updating %s.", f, paste(review$accepted, collapse = ", ")))
      write_in_place(f, parsed, new_block)
      updated <- f
      run$applied <- review$applied
    }
  }

  merged <- merge_roxygen_findings(state, f, run, ctx$reviewed_sha, source_block$user_edited)
  list(state = merged$state, stats = merged$stats, updated = updated)
}
