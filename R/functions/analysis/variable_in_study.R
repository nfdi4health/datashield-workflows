# Whether the variable `v` exists in the study `server`: true unless its
# `studies` list (from the variables file) names some of the plan's
# `servers` but not this one. A list naming none of the plan's servers
# (e.g. a file written while logged in to other server names) is ignored,
# so a mismatch never removes a variable everywhere.
variable_in_study <- function(v, server, servers) {
  listed <- as.character(unlist(v$studies))
  if (length(intersect(listed, servers)) == 0) {
    return(TRUE)
  }
  server %in% listed
}
