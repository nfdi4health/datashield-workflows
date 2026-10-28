# Runs the project's scripts the way main.R does in testing mode
# (R_CONFIG_ACTIVE = `profile`, the project's test profile): the DSLite
# setup first (mock data), then `scripts` in order, all in one fresh R
# session. Returns list(login_error, errors, objects, timed_out): errors
# is a character vector named by script path, NA when the script ran
# through; objects lists what is on the servers afterwards (names, and
# with dsBaseClient classes and columns), when `connections` names the
# connections object — for the next step's prompt. If the whole run
# exceeds `timeout` seconds it is stopped; timed_out is then TRUE, and
# which script hung is unknown.
#
# The session starts without the project's .Rprofile (a dsAnalysis
# project activates renv there, which would hide the packages installed
# for this run), and without the API and GitHub tokens: the scripts are
# generated code. That list is deliberately not a setting, so no project
# override can hand the tokens to generated code.
run_analysis_scripts <- function(login_file, scripts, profile, timeout, connections = NULL) {
  child <- function(login_file, scripts, profile, connections) {
    Sys.setenv(R_CONFIG_ACTIVE = profile)
    describe_objects <- function(expr) {
      out <- character(0)
      for (s in unique(all.vars(expr))) {
        if (!exists(s, envir = globalenv(), inherits = FALSE)) {
          next
        }
        obj <- get(s, envir = globalenv())
        if (is.function(obj)) {
          next
        }
        d <- paste(utils::capture.output(utils::str(obj, max.level = 2, give.attr = FALSE, vec.len = 3)), collapse = "\n")
        out <- c(out, sprintf("%s: %s", s, substr(d, 1, 500)))
      }
      paste(utils::head(out, 6), collapse = "\n")
    }
    run <- function(path) {
      exprs <- tryCatch(parse(path, keep.source = FALSE), error = function(e) e)
      if (inherits(exprs, "error")) {
        return(conditionMessage(exprs))
      }
      for (i in seq_along(exprs)) {
        res <- tryCatch({
          eval(exprs[[i]], envir = globalenv())
          NA_character_
        }, error = function(e) {
          msg <- conditionMessage(e)
          ds <- tryCatch(unlist(DSI::datashield.errors()), error = function(e2) character(0))
          if (length(ds) > 0) {
            msg <- paste0(msg, " Server errors: ", substr(paste(ds, collapse = " | "), 1, 1500))
          }
          stmt <- paste(deparse(exprs[[i]], width.cutoff = 500L), collapse = " ")
          objs <- tryCatch(describe_objects(exprs[[i]]), error = function(e2) "")
          used <- ""
          if (nzchar(objs)) {
            used <- paste0("\nObjects used in that statement:\n", objs)
          }
          paste0(msg, " [failing statement: ", substr(stmt, 1, 400), "]", used)
        })
        if (!is.na(res)) {
          return(res)
        }
      }
      NA_character_
    }
    # What the scripts left on the servers, for the next step's prompt:
    # names, and with dsBaseClient also classes and data frame columns.
    server_objects <- function(connections) {
      if (is.null(connections) || !exists(connections, envir = globalenv())) {
        return("")
      }
      conns <- get(connections, envir = globalenv())
      symbols <- sort(unique(unlist(DSI::datashield.symbols(conns))))
      if (length(symbols) == 0) {
        return("")
      }
      describe <- requireNamespace("dsBaseClient", quietly = TRUE)
      lines <- vapply(utils::head(symbols, 40), function(s) {
        if (!describe) {
          return(sprintf("- `%s`", s))
        }
        cls <- tryCatch(unique(unlist(dsBaseClient::ds.class(s, datasources = conns))), error = function(e) character(0))
        extra <- ""
        if ("data.frame" %in% cls) {
          dims <- tryCatch(unlist(dsBaseClient::ds.dim(s, type = "combine", datasources = conns))[1:2], error = function(e) NULL)
          cols <- tryCatch(unique(unlist(dsBaseClient::ds.colnames(s, datasources = conns))), error = function(e) character(0))
          if (length(dims) == 2) {
            extra <- sprintf(", %s rows x %s columns in total", dims[1], dims[2])
          }
          extra <- sprintf("%s; columns: %s", extra, paste(utils::head(cols, 40), collapse = ", "))
        }
        class_text <- "class unknown"
        if (length(cls) > 0) {
          class_text <- paste(cls, collapse = "/")
        }
        sprintf("- `%s` (%s%s)", s, class_text, extra)
      }, character(1))
      paste(lines, collapse = "\n")
    }
    login_error <- run(login_file)
    if (!is.na(login_error)) {
      return(list(login_error = login_error, errors = character(0), objects = ""))
    }
    errors <- vapply(scripts, run, character(1), USE.NAMES = FALSE)
    objects <- tryCatch(server_objects(connections), error = function(e) "")
    list(login_error = NA_character_, errors = stats::setNames(errors, scripts), objects = objects)
  }
  scripts <- unname(scripts)  # results are looked up by path, whatever names came in
  env <- callr::rcmd_safe_env()
  # No credentials for the analyst's scripts — also nothing to get new ones with.
  env[credential_variables()] <- ""
  tryCatch(
    c(callr::r(child, args = list(login_file = login_file, scripts = scripts, profile = profile, connections = connections), user_profile = FALSE, env = env, timeout = timeout),
      list(timed_out = FALSE)),
    callr_timeout_error = function(e) list(login_error = NA_character_, errors = stats::setNames(rep(NA_character_, length(scripts)), scripts), objects = "", timed_out = TRUE),
    error = function(e) list(login_error = sprintf("The test run failed: %s", conditionMessage(e)), errors = character(0), objects = "", timed_out = FALSE)
  )
}
