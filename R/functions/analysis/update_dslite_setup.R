# Points the project's DSLite test setup at the bot's mock data and adds
# missing server packages, using dsAnalysis's own functions
# (update_MockData(), add_dsPackage(), with their helpers: all of its R/),
# sourced from a checkout of the
# dsAnalysis repository, so dsAnalysis stays the only owner of that file's
# format. Returns the setup file's path, or NULL with a message if the
# project has no DSLite setup or dsAnalysis isn't available.
#
# add_dsPackage() breaks the file when every given package is already
# there (dev-notes/analysis-suggest.md, dsAnalysis checklist), so it is
# only called with packages its own check wouldn't find: those not named
# in the lines above `mock_data_marker` (the library() calls).
# `mock_folder` is the mock data's folder name (update_MockData() looks
# for it under utils/mock_data), `servers` the studies it holds files for.
# The login's `symbol = "..."` is set to the plan's `symbol`: the template
# says "D", and neither dsAnalysis function changes it, so a plan with
# another symbol would otherwise fail every step in the test run. For the
# same reason, if the real login names its connections differently
# (`connections`, from check_login_file()) than the DSLite setup does
# (`conns` in the template), a marked line at the end provides that name.
update_dslite_setup <- function(setup_file, dsanalysis_dir, mock_folder, servers, server_packages, mock_data_marker, symbol, connections) {
  if (!file.exists(setup_file)) {
    message(sprintf("No DSLite setup at %s — skipping its update.", setup_file))
    return(NULL)
  }
  # All of dsAnalysis' R/ is loaded: it keeps one function per file, so
  # add_dsPackage() and update_MockData() need their helpers' files too.
  # Loading only defines functions; nothing runs.
  needed <- file.path(dsanalysis_dir, "R", c("update_MockData.R", "add_dsPackage.R"))
  if (!all(file.exists(needed))) {
    message(sprintf("dsAnalysis functions not found in %s — skipping the DSLite setup update.", dsanalysis_dir))
    return(NULL)
  }
  env <- new.env()
  for (f in list.files(file.path(dsanalysis_dir, "R"), pattern = "[.][Rr]$", full.names = TRUE)) {
    sys.source(f, envir = env)
  }

  # update_MockData() pairs the files it lists with these names, in
  # list.files() order: byte order, as sort(method = "radix") gives.
  env$update_MockData(folder_name = mock_folder, table_names = sort(servers, method = "radix"))

  lines <- readLines(setup_file, warn = FALSE)
  marker_line <- which(lines == mock_data_marker)
  block1 <- if (length(marker_line) > 0) {
    lines[seq_len(marker_line[1] - 1)]
  } else {
    lines
  }
  missing <- server_packages[!vapply(server_packages, function(p) any(grepl(p, block1, fixed = TRUE)), logical(1))]
  if (length(missing) > 0) {
    env$add_dsPackage(missing)
  }

  lines <- gsub("symbol\\s*=\\s*\"[^\"]*\"", sprintf("symbol = \"%s\"", symbol), readLines(setup_file, warn = FALSE))
  alias_marker <- "# bot-suggest: the connections' name in the real login file"
  lines <- lines[!endsWith(lines, alias_marker)]
  login_call <- regmatches(lines, regexpr("^\\s*[A-Za-z.][A-Za-z0-9._]*\\s*(<<-|<-|=)\\s*(DSI::)?datashield\\.login", lines))
  own_name <- if (length(login_call) > 0) {
    sub("^\\s*([A-Za-z.][A-Za-z0-9._]*).*$", "\\1", login_call[1])
  } else {
    connections
  }
  if (!identical(own_name, connections)) {
    lines <- c(lines, sprintf("%s <<- %s  %s", connections, own_name, alias_marker))
  }
  writeLines(lines, setup_file)
  setup_file
}
