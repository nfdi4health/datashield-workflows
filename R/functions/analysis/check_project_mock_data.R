# Checks the analyst's own mock data, named in the plan's `mock-data`
# (a folder under `mock_root`, i.e. utils/mock_data, as written by
# dsAnalysis's initMockData()): the folder exists, isn't the workflow's
# own `bot_folder`, and holds one `<server>.rda` per study of the plan,
# each with an object named after its server (what update_MockData()
# expects). Stops with every problem at once (wording from `texts$plan`),
# before anything runs: there is no silent fallback to generated data.
# Returns the folder name.
check_project_mock_data <- function(folder, plan, mock_root, bot_folder, texts) {
  say <- function(key, ...) fill_template(texts$plan[[key]], list(FOLDER = folder, ...))
  if (identical(folder, bot_folder)) {
    stop(say("mock_folder_reserved"), call. = FALSE)
  }
  path <- file.path(mock_root, folder)
  if (!dir.exists(path)) {
    stop(say("mock_folder_missing"), call. = FALSE)
  }
  servers <- vapply(plan$studies, function(s) s$server, character(1))
  expected <- paste0(servers, ".rda")
  missing <- expected[!file.exists(file.path(path, expected))]
  if (length(missing) > 0) {
    stop(say("mock_files", EXPECTED = paste(expected, collapse = ", "), MISSING = paste(missing, collapse = ", ")), call. = FALSE)
  }
  problems <- character(0)
  for (i in seq_along(servers)) {
    env <- new.env()
    found <- tryCatch(load(file.path(path, expected[i]), envir = env), error = function(e) character(0))
    if (!identical(found, servers[i]) || !is.data.frame(env[[servers[i]]])) {
      problems <- c(problems, say("mock_object", FILE = expected[i], SERVER = servers[i],
        FOUND = if (length(found) > 0) paste(found, collapse = ", ") else "-"))
    }
  }
  if (length(problems) > 0) {
    stop(paste(problems, collapse = "\n"), call. = FALSE)
  }
  folder
}
