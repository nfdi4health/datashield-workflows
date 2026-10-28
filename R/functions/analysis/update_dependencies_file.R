# Updates the bot's block in dependencies.R (dependencies_block()),
# between `markers$dependencies_start` and `markers$dependencies_end`.
# Packages "not yet on the servers" come from this run's notes
# (`other_packages`, server package names; their clients are added by
# name) plus those the block already lists: their steps may not have been
# requested this time. They stay until the servers have them.
# Returns update_marked_block()'s result ("changed", "unchanged",
# "damaged").
update_dependencies_file <- function(path, clients, servers, other_packages, catalogue, settings, texts) {
  start <- settings$markers$dependencies_start
  end <- settings$markers$dependencies_end
  lines <- if (file.exists(path)) {
    readLines(path, warn = FALSE)
  } else {
    character(0)
  }
  block <- if (sum(lines == start) == 1 && sum(lines == end) == 1) {
    lines[which(lines == start):which(lines == end)]
  } else {
    character(0)
  }
  listed <- sub("^# library\\((.+)\\)$", "\\1", grep("^# library\\(.+\\)$", block, value = TRUE))

  new <- unlist(lapply(other_packages, function(p) c(client_package_name(p, catalogue, settings$client_suffix), p)))
  not_on_servers <- setdiff(unique(c(listed, new[!is.na(new)])), c(clients, servers))
  update_marked_block(path, start, end, dependencies_block(clients, servers, not_on_servers, texts))
}
