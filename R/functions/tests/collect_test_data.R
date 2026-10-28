# Runs in a separate R process (started by summarize_test_data()), so the
# setup code's logins and global assignments stay out of the main run.
# Loads the package from source and sources the test setup/helper files
# the way testthat does — from tests/testthat/, helpers before setup — then
# describes the data tables they create: the tables inside any DSLite
# server (read through a temporary DSLite session), or else plain data
# frames. Structure only: rows, columns, types, NA counts and factor level
# counts. Writes one line per table to `out`.
collect_test_data <- function(files, out) {
  describe <- function(label, df) {
    cols <- vapply(names(df), function(col) {
      x <- df[[col]]
      if (is.factor(x)) {
        # Up to 10 levels with their counts.
        counts <- table(x)
        shown <- utils::head(counts, 10)
        detail <- sprintf("factor: %s", paste(sprintf("\"%s\" ×%d", names(shown), as.integer(shown)), collapse = ", "))
        if (length(counts) > 10) {
          detail <- sprintf("%s, … %d levels", detail, length(counts))
        }
      } else {
        detail <- class(x)[1]
      }
      nas <- sum(is.na(x))
      if (nas > 0) {
        detail <- sprintf("%s; %d missing", detail, nas)
      }
      sprintf("%s (%s)", col, detail)
    }, character(1))
    sprintf("- %s: %d rows — %s", label, nrow(df), paste(cols, collapse = "; "))
  }

  problems <- character(0)
  lines <- tryCatch({
    suppressMessages(pkgload::load_all(".", quiet = TRUE))
    env <- new.env(parent = globalenv())
    setwd(file.path("tests", "testthat"))
    # As during a test run: testthat::test_path() and other helpers check
    # TESTTHAT, and without it look for tests/testthat below this folder.
    Sys.setenv(TESTTHAT = "true", TESTTHAT_PKG = read.dcf(file.path("..", "..", "DESCRIPTION"), "Package")[[1]])
    # A file failing partway (e.g. at the login) still leaves the tables it
    # created before — describe those, and say what failed.
    for (f in basename(files)) {
      tryCatch(suppressMessages(source(f, local = env)), error = function(e) {
        problems <<- c(problems, sprintf("(`%s` stopped with an error, the summary may be incomplete: %s)", f, conditionMessage(e)))
      })
    }

    objects <- c(mget(ls(env), envir = env), mget(ls(globalenv()), envir = globalenv()))
    servers <- Filter(function(x) inherits(x, "DSLiteServer"), objects)
    tables <- list()
    if (length(servers) > 0) {
      for (s in unique(names(servers))) {
        srv <- servers[[s]]
        sid <- srv$newSession()
        for (t in srv$tableNames()) {
          srv$assignTable(sid, ".described_table", t)
          tables[[sprintf("DSLite server `%s`, table `%s`", s, t)]] <- srv$getSessionData(sid, ".described_table")
        }
        srv$closeSession(sid)
      }
    } else {
      frames <- Filter(is.data.frame, objects)
      names(frames) <- sprintf("`%s`", names(frames))
      tables <- frames
    }

    if (length(tables) == 0) {
      "(no data tables found)"
    } else {
      vapply(names(tables), function(n) describe(n, tables[[n]]), character(1))
    }
  }, error = function(e) sprintf("(could not be determined: %s)", conditionMessage(e)))

  writeLines(c(lines, problems), out)
}
