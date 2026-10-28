# User-facing functions of a package whose names don't follow
# `functions` in the rules (client ds.camelCase, server nameDS); listed
# prefixes and namespaced forms count as following while those rules are
# open. Report only: function renames are not part of the apply workflow.
check_function_names <- function(pkg, rules) {
  r <- rules$functions[[pkg$side]]
  ok <- grepl(r$pattern, pkg$user_facing, perl = TRUE)
  for (p in c(unlist(r$allowed_prefixes), unlist(r$namespaced))) {
    ok <- ok | startsWith(pkg$user_facing, p)
  }
  pkg$user_facing[!ok]
}
