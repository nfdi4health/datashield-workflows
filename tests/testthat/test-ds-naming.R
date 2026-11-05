# DataSHIELD argument naming: classification, proposals, collisions, the
# rename machinery, and check + apply end to end on the made-up
# client/server pair (tests/fixtures/ds-client, ds-server).

rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-argument-rules.yml"))

test_that("the rules file reads one-letter values as text, not booleans", {
  expect_equal(rules$style$abbreviations$number, "n")
  expect_equal(unlist(rules$multiple_inputs$pair$vector), c("x", "y"))
})

test_that("check_package_names() checks names and pairs, with the listed exceptions", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  client <- function(name) list(name = name, side = "client")
  server <- function(name) list(name = name, side = "server")
  expect_length(check_package_names(client("dsFooClient"), server("dsFoo"), package_rules), 0)
  expect_length(check_package_names(server("dsFoo"), client("dsFooClient"), package_rules), 0)
  expect_match(check_package_names(client("dsFooClient"), server("dsBar"), package_rules), "expected the client `dsBarClient`")
  expect_match(check_package_names(client("fooClient"), server("dsFoo"), package_rules)[1], "doesn't follow")
  expect_length(check_package_names(client("dsMTLClient"), server("dsMTLBase"), package_rules), 0)
  expect_length(check_package_names(client("dsHelper"), NULL, package_rules), 0)          # client only
  expect_length(check_package_names(server("dsResource"), NULL, package_rules), 0)        # server only
  expect_match(check_package_names(client("dsFooClient"), NULL, package_rules), "No paired package")
})

test_that("check_description_fields() names what's missing, not what it says", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  dir <- withr::local_tempdir()
  fields <- function(lines) {
    writeLines(c("Package: dsFoo", lines), file.path(dir, "DESCRIPTION"))
    check_description_fields(list(dir = dir), package_rules)
  }
  expect_length(fields(c("License: MIT + file LICENSE", "Authors@R: person('A', 'B')", "URL: https://x.org", "BugReports: https://x.org/i")), 0)
  expect_identical(fields("License: GPL-3"), "Missing in `DESCRIPTION`: `Authors@R`, `URL`, `BugReports`.")
})

test_that("check_function_files() wants one function per file, named after it", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  defs <- list(list(name = "ds.mean", file = "R/ds.mean.R"), list(name = "ds.sum", file = "R/utils.R"), list(name = "helper", file = "R/utils.R"))
  found <- check_function_files(list(defs = defs, user_facing = c("ds.mean", "ds.sum")), package_rules)
  expect_identical(found, c("`utils.R` holds several functions: `ds.sum`, `helper`.", "`ds.sum` is in `utils.R`, expected `ds.sum.R`."))
})

test_that("check_roxygen_tags() names missing tags of user-facing functions", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  common <- c("title", "description", "details", "return", "author")
  defs <- list(
    list(name = "ds.ok", args = c("x", "..."), param_docs = list(x = "a"), tags = c(common, "param", "examples")),
    list(name = "ds.bad", args = c("x", "y"), param_docs = list(x = "a"), tags = c("param")),
    list(name = "ds.inherit", args = "x", param_docs = list(), tags = c(common, "examples", "inheritParams")),
    list(name = "ds.template", args = "x", param_docs = list(), tags = c(common, "examples", "template")),
    list(name = "helper", args = "x", param_docs = list(), tags = character(0))
  )
  pkg <- list(side = "client", defs = defs, user_facing = c("ds.ok", "ds.bad", "ds.inherit", "ds.template"))
  expect_identical(check_roxygen_tags(pkg, package_rules), "`ds.bad`: missing title, description, details, return, author, examples, param (y).")
  pkg$side <- "server"                                           # examples: client only
  pkg$defs[[1]]$tags <- setdiff(pkg$defs[[1]]$tags, "examples")
  pkg$user_facing <- "ds.ok"
  expect_length(check_roxygen_tags(pkg, package_rules), 0)
})

test_that("check_required_files() names what a package lacks", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  dir <- withr::local_tempdir()
  expect_identical(check_required_files(list(dir = dir), package_rules), "Missing: `README.md`, `tests/testthat`.")
  dir.create(file.path(dir, "tests", "testthat"), recursive = TRUE)
  writeLines("# dsFoo", file.path(dir, "README.md"))
  expect_length(check_required_files(list(dir = dir), package_rules), 0)
})

test_that("check_server_methods() wants inst/DATASHIELD and a function behind each method", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "inst"))
  dir.create(file.path(dir, "R"))
  writeLines("Package: dsFoo", file.path(dir, "DESCRIPTION"))
  writeLines(c("AggregateMethods:", "    meanDS,", "    goneDS,", "    asChar=base::as.character"), file.path(dir, "inst", "DATASHIELD"))
  writeLines("meanDS <- function(x) x", file.path(dir, "R", "meanDS.R"))
  expect_identical(check_server_methods(read_ds_package(dir, "server", unlist(package_rules$`function`$server$method_types)), package_rules), "Declared without a function: `goneDS`.")

  file.remove(file.path(dir, "inst", "DATASHIELD"))
  writeLines(c("Package: dsFoo", "AggregateMethods: meanDS"), file.path(dir, "DESCRIPTION"))
  found <- check_server_methods(read_ds_package(dir, "server", unlist(package_rules$`function`$server$method_types)), package_rules)
  expect_match(found[1], "No `inst/DATASHIELD`")
  expect_match(found[2], "declared in `DESCRIPTION`")
})

test_that("check_client_server_pairing() goes by the calls, not by comparing names", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "R"))
  writeLines("Package: dsFooClient", file.path(dir, "DESCRIPTION"))
  writeLines("export(ds.glm, ds.local)", file.path(dir, "NAMESPACE"))
  writeLines(c("ds.glm <- function(x) {", "  a <- call(\"glm1DS\", x)", "  b <- paste0(\"glm2DS(\", x, \")\")", "  DSI::datashield.aggregate(x, \"lsDS()\")",
               "  helper(x)", "}"), file.path(dir, "R", "ds.glm.R"))
  writeLines(c("helper <- function(x) call(\"helperDS\", x)"), file.path(dir, "R", "helper.R"))
  writeLines(c("ds.local <- function(x) stop(paste0(\"sum(\", x[, 1]))"), file.path(dir, "R", "ds.local.R"))  # empty argument
  client <- read_ds_package(dir, "client", character(0))
  expect_setequal(client_server_calls(client)$method, c("glm1DS", "glm2DS", "lsDS", "helperDS"))

  server <- list(name = "dsFoo", methods = c(glm1DS = "glm1DS", glm2DS = "glm2DS", lsDS = "lsDS", helperDS = "helperDS"))
  expect_length(check_client_server_pairing(client, server), 0)
  server$methods <- structure(c(glm1DS = "glm1DS", lsDS = "lsDS", helperDS = "helperDS", oldDS = "oldDS", sum = "sum"), other_package = "sum")
  found <- check_client_server_pairing(client, server)
  expect_match(found[1], "`ds.glm` calls `glm2DS`, which `dsFoo` doesn't declare")
  expect_match(found[2], "no client function calls it: `oldDS`")
})

test_that("test_file_pattern() builds the test file name regex from its parts", {
  package_rules <- yaml::read_yaml(file.path(repo_root, "config", "ds-package-rules.yml"))
  pattern <- test_file_pattern(package_rules, "client")
  server <- test_file_pattern(package_rules, "server")
  expect_true(all(grepl(pattern, unlist(package_rules$tests$examples), perl = TRUE)))
  expect_equal(pattern, "^test-((?<category>(smk|arg|perf|disc|discctrl|datachk|expt|math|dgr)(_(smk|arg|perf|disc|discctrl|datachk|expt|math|dgr|bug))*)-)?(?<function>ds\\.[a-z][A-Za-z0-9]*)(-[a-z0-9_]+)?\\.R$")
  expect_true(grepl(server, "test-smk-glm1DS.R", perl = TRUE))
  expect_false(any(grepl(server, c("test-smk-glmDS1.R", "test-smk-ds.mean.R"), perl = TRUE)))
  expect_false(grepl(pattern, "test-smk-meanDS.R", perl = TRUE))
  ok <- c("test-ds.mean.R", "test-smk-ds.mean.R", "test-smk_expt-ds.mean.R", "test-expt_bug-ds.table.R",
          "test-smk_dgr-ds.recodeValues-factor_missing.R")
  expect_true(all(grepl(pattern, ok, perl = TRUE)))
  expect_false(any(grepl(pattern, c("test-_-vm-test.R", "test-bug-ds.mean.R", "ds.mean.R"), perl = TRUE)))
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

test_that("ds_object_class() tells the three omics families apart", {
  expect_equal(ds_object_class("a character string naming an ExpressionSet")$class, "eset")
  expect_equal(ds_object_class("the name of a RangedSummarizedExperiment")$class, "eset")
  expect_equal(ds_object_class("the name of a GenotypeData object")$class, "genotype")
  expect_equal(ds_object_class("the name of a GDS file connection")$class, "genotype")
  expect_equal(ds_object_class("the name of an ExposomeSet")$class, "exposome")
  expect_identical(ds_object_class("an image asset")$class, "")
  expect_equal(propose_ds_name("genoData", "object", "genotype", "pkg", rules)$match, "alias")
  expect_equal(propose_ds_name("x", "object", "exposome", "pkg", rules)$proposed, "exposome")
})

test_that("to_naming_style() splits camelCase and keeps acronym plurals together", {
  expect_equal(to_naming_style("idCol", ".", "lowercase"), "id.col")
  expect_equal(to_naming_style("nBreaks", ".", "lowercase"), "n.breaks")
  expect_equal(to_naming_style("keep.NAs", ".", "lowercase"), "keep.nas")
  expect_equal(to_naming_style("time_col", ".", "lowercase"), "time.col")
  expect_equal(to_naming_style("idCol", ".", "any"), "id.Col")       # style$case decides
})

test_that("propose_ds_name() follows roles, classes, columns and exceptions", {
  expect_equal(propose_ds_name("newobj.name", "new_object", "", "pkg", rules)$proposed, "newobj")
  expect_equal(propose_ds_name("dataName", "object", "data.frame", "pkg", rules)$proposed, "df")
  expect_equal(propose_ds_name("by.x.names", "column", "", "pkg", rules)$proposed, "by.x.names")
  expect_equal(propose_ds_name("idCol", "column", "", "pkg", rules)$proposed, "id.col")
  expect_equal(propose_ds_name("formula", "object", "formula", "pkg", rules)$match, "exception")
  expect_true(is.na(propose_ds_name("extra", "unknown", "", "pkg", rules)$proposed))
})

test_that("resolve_naming_collisions() gives two vectors the pair, in any function", {
  vectors <- function(args, confidence = "high") {
    data.frame(`function` = "ds.any", arg = args, proposed = "x", rule = "classes.vector", rule_open = FALSE,
               match = "rule", class = "vector", confidence = confidence, note = "", check.names = FALSE)
  }
  expect_equal(resolve_naming_collisions(vectors(c("V1", "V2")), rules)$proposed, c("x", "y"))
  expect_equal(resolve_naming_collisions(vectors(c("V1", "V2", "V3")), rules)$proposed, c("x1", "x2", "x3"))
  expect_true(all(is.na(resolve_naming_collisions(vectors(c("V1", "V2"), "medium"), rules)$proposed)))
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
  expect_true(any(grepl("function(df1, df2, by.x.names, newobj", merge_code, fixed = TRUE)))
  expect_true(any(grepl("\tcalltext <- call", merge_code, fixed = TRUE)))   # tabs kept
  expect_true(any(grepl("ds.merge(df1 = \"D\"", readLines(file.path(dir, "vignettes", "intro.Rmd")), fixed = TRUE)))
  expect_true(any(grepl("meanDS <- function(x)", readLines(file.path(dir, ".ds-naming-server", "R", "meanDS.R")), fixed = TRUE)))

  before <- tools::md5sum(list.files(file.path(dir, "R"), full.names = TRUE))
  apply2 <- run_entry_script("apply_ds_naming.R", dir, env)
  expect_equal(apply2$status, 0L)
  expect_equal(tools::md5sum(list.files(file.path(dir, "R"), full.names = TRUE)), before)
})
