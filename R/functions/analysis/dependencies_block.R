# The bot's block in dependencies.R (the file exists so renv records
# packages without a library() call in the scripts). Three parts, headed
# by `texts$dependencies`: the tested client packages, the server
# packages needed for local DSLite testing, and — commented out, so renv
# ignores them — packages from notes that the study servers don't have yet.
dependencies_block <- function(clients, servers, not_on_servers, texts) {
  block <- c(
    texts$dependencies$clients,
    sprintf("library(%s)", clients),
    texts$dependencies$servers,
    "library(DSLite)",
    sprintf("library(%s)", servers)
  )
  if (length(not_on_servers) > 0) {
    block <- c(block, unlist(texts$dependencies$not_on_servers), sprintf("# library(%s)", not_on_servers))
  }
  block
}
