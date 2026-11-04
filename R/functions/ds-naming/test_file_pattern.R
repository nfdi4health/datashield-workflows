# The regular expression for test file names of one side ("client" or
# "server"): the template `tests$pattern` of the package rules with its
# placeholders filled in. <category> is one category or several joined by
# `category_joiner`, where a qualifier (e.g. bug) may only follow a
# category; <function> is that side's function name pattern, without its
# anchors; <variant> comes from `tests$variant`. The groups `category` and
# `function` are read by check_test_file_names().
test_file_pattern <- function(package_rules, side) {
  tests <- package_rules$tests
  categories <- names(tests$categories)
  after_first <- c(categories, names(tests$qualifiers))
  category <- sprintf("(?<category>(%s)(%s(%s))*)", paste(categories, collapse = "|"), tests$category_joiner,
                      paste(after_first, collapse = "|"))
  fn <- gsub("^\\^|\\$$", "", package_rules$functions[[side]]$pattern)
  pattern <- sub("<category>", category, tests$pattern, fixed = TRUE)
  pattern <- sub("<function>", sprintf("(?<function>%s)", fn), pattern, fixed = TRUE)
  sub("<variant>", tests$variant, pattern, fixed = TRUE)
}
