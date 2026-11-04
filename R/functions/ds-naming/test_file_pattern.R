# The regular expression for test file names: the template `pattern` of
# `tests` in the package rules with its placeholders filled in. <category>
# is one category or several joined by `category_joiner`, where a qualifier
# (e.g. bug) may only follow a category; <target> and <variant> come from
# the keys of those names. The groups `category` and `target` are read by
# check_test_file_names().
test_file_pattern <- function(tests) {
  categories <- names(tests$categories)
  after_first <- c(categories, names(tests$qualifiers))
  category <- sprintf("(?<category>(%s)(%s(%s))*)", paste(categories, collapse = "|"), tests$category_joiner,
                      paste(after_first, collapse = "|"))
  pattern <- sub("<category>", category, tests$pattern, fixed = TRUE)
  pattern <- sub("<target>", sprintf("(?<target>%s)", tests$target), pattern, fixed = TRUE)
  sub("<variant>", tests$variant, pattern, fixed = TRUE)
}
