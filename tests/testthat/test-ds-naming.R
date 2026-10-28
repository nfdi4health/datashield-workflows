# DataSHIELD argument naming: classification, proposals, collisions, the
# rename machinery, and check + apply end to end on the made-up
# client/server pair (tests/fixtures/ds-client, ds-server).

rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-naming-rules.yml"))

test_that("the rules file reads one-letter values as text, not booleans", {
  expect_equal(rules$style$abbreviations$number, "n")
  expect_equal(unlist(rules$multiple_inputs$exceptions[[1]]$names), c("x", "y"))
})

test_that("classify_ds_argument() recognises roles and classes from docs and names", {
  expect_equal(classify_ds_argument("datasources", "NULL", "a list of DSConnection-class objects")$role, "connection")
  expect_equal(classify_ds_argument("type", "\"split\"", "\"split\" or \"combine\"")$role, "output_type")
  expect_equal(classify_ds_argument("newobj.name", "NULL", "")$role, "new_object")
  expect_false(classify_ds_argument("output.type", "\"link\"", "")$role == "new_object")  # name regex is anchored
  df <- classify_ds_argument("x.name", "", "a character string naming the first data frame.")
  expect_equal(df[c("role", "class")], list(role = "object", class = "data.frame"))
  expect_equal(classify_ds_argument("idCol", "", "the name of the ID column in the data frame.")$role, "column")
  expect_equal(classify_ds_argument("by.x.names", "", "names of the column(s) in data frame x to merge by")$role, "column")
  expect_equal(classify_ds_argument("force.nfilter", "NULL", "it must be specified as a positive integer")$class, "numeric")
  expect_equal(classify_ds_argument("extra", "NULL", "")$role, "unknown")
})

test_that("to_naming_style() splits camelCase and keeps acronym plurals together", {
  expect_equal(to_naming_style("idCol", "."), "id.col")
  expect_equal(to_naming_style("nBreaks", "."), "n.breaks")
  expect_equal(to_naming_style("keep.NAs", "."), "keep.nas")
  expect_equal(to_naming_style("time_col", "."), "time.col")
})

test_that("propose_ds_name() follows roles, classes, columns and exceptions", {
  expect_equal(propose_ds_name("newobj.name", "new_object", "", "pkg", rules)$proposed, "newobj")
  expect_equal(propose_ds_name("dataName", "object", "data.frame", "pkg", rules)$proposed, "df")
  expect_equal(propose_ds_name("by.x.names", "column", "", "pkg", rules)$proposed, "by.x.cols")
  expect_equal(propose_ds_name("formula", "object", "formula", "pkg", rules)$match, "exception")
  expect_true(is.na(propose_ds_name("extra", "unknown", "", "pkg", rules)$proposed))
})

test_that("resolve_naming_collisions() numbers generic inputs only and never roles", {
  rows <- data.frame(`function` = "ds.f", arg = c("x.name", "y.name", "sex"), proposed = c("df", "df", "df"),
                     rule = "classes.data.frame", rule_open = FALSE, match = "rule", class = "data.frame",
                     confidence = "high", note = "", check.names = FALSE)
  r <- resolve_naming_collisions(rows, rules)
  expect_equal(r$proposed, c("df1", "df2", "sex"))  # descriptive name kept
  roles <- data.frame(`function` = "ds.g", arg = c("checks", "check.rows"), proposed = c("checks", "checks"),
                      rule = "roles.checks", rule_open = FALSE, match = c("canonical", "rule"), class = "",
                      confidence = "high", note = "", check.names = FALSE)
  r <- resolve_naming_collisions(roles, rules)
  expect_equal(r$proposed[1], "checks")
  expect_true(is.na(r$proposed[2]))
  expect_equal(r$match[2], "conflict")
})

test_that("rename_call_args_text() renames only direct arguments of the call", {
  lines <- c("x <- ds.f(old = 1, g(old = 2), 'old =' , old == 3)", "ds.f(", "  old = 4)")
  res <- rename_call_args_text(lines, "ds.f", "old", "new")
  expect_equal(res$lines, c("x <- ds.f(new = 1, g(old = 2), 'old =' , old == 3)", "ds.f(", "  new = 4)"))
  expect_equal(res$done, 2)
})

test_that("find_r_rename_edits() + apply_token_edits() rename formals, uses and calls by parse data", {
  lines <- c("f <- function(a,\told = 1) {", "\tx$old + old; g(old = old)", "}", "f(old = 2)")
  found <- find_r_rename_edits(lines, data.frame(fn = "f", old = "old", new = "new"))
  res <- apply_token_edits(lines, found$edits)
  expect_equal(res$lines, c("f <- function(a,\tnew = 1) {", "\tx$old + new; g(old = new)", "}", "f(new = 2)"))
  expect_length(res$skipped, 0)
})

test_that("rename_in_roxygen() finds the block across a blank line and renames @param", {
  lines <- c("#' @param old the thing", "#' @examples", "#'", "", "#' f(old = 1)", "f <- function(old) old")
  res <- rename_in_roxygen(lines, data.frame(fn = "f", old = "old", new = "new"))
  expect_equal(res$lines[1], "#' @param new the thing")
  expect_equal(res$lines[5], "#' f(new = 1)")
})

test_that("check and apply run end to end on the fixture pair and apply is idempotent", {
  dir <- local_fixture("ds-client")
  file.copy(file.path(repo_root, "tests", "fixtures", "ds-server"), dir, recursive = TRUE)
  file.rename(file.path(dir, "ds-server"), file.path(dir, ".ds-naming-server"))
  env <- c(SERVER_DIR = ".ds-naming-server", USE_CLAUDE = "false", GITHUB_REPOSITORY = "me/dsFixClient",
           GITHUB_SHA = "abc", SERVER_REPOSITORY = "me/dsFix", SERVER_SHA = "def", GITHUB_STEP_SUMMARY = "")
  check <- run_entry_script("check_ds_naming.R", dir, env)
  expect_equal(check$status, 0L, info = paste(check$output, collapse = "\n"))
  file <- file.path(dir, ".github", "ds-naming", "transformations.yml")
  entries <- yaml::read_yaml(file)$entries
  ids <- vapply(entries, function(e) e$id, "")
  expect_true("dsFix::meanDS::xvect" %in% ids)        # server arg follows the client's x
  expect_true("dsFixClient::ds.merge::newobj.name" %in% ids)

  writeLines(sub("status: proposed", "status: approved", readLines(file)), file)
  apply1 <- run_entry_script("apply_ds_naming.R", dir, env)
  expect_equal(apply1$status, 0L, info = paste(apply1$output, collapse = "\n"))
  merge_code <- readLines(file.path(dir, "R", "ds.merge.R"))
  expect_true(any(grepl("function(df1, df2, by.x.cols, newobj", merge_code, fixed = TRUE)))
  expect_true(any(grepl("\tcalltext <- call", merge_code, fixed = TRUE)))   # tabs kept
  expect_true(any(grepl("ds.merge(df1 = \"D\"", readLines(file.path(dir, "vignettes", "intro.Rmd")), fixed = TRUE)))
  expect_true(any(grepl("meanDS <- function(x)", readLines(file.path(dir, ".ds-naming-server", "R", "meanDS.R")), fixed = TRUE)))

  before <- tools::md5sum(list.files(file.path(dir, "R"), full.names = TRUE))
  apply2 <- run_entry_script("apply_ds_naming.R", dir, env)
  expect_equal(apply2$status, 0L)
  expect_equal(tools::md5sum(list.files(file.path(dir, "R"), full.names = TRUE)), before)
})
