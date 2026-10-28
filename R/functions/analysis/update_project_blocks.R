# Updates the bot's two blocks in the project after scripts were written:
# in main.R the source() lines of all bot scripts in file order, and in
# dependencies.R the package lists (update_dependencies_file()), with the
# packages from this run's "other package" notes. Returns the notes for
# the report: one per block left alone because its markers are damaged.
update_project_blocks <- function(steps, installed, catalogue, settings, texts) {
  paths <- settings$paths
  scripts <- basename(sort(find_bot_step_files(paths$scripts)$path))
  main_block <- update_marked_block(paths$main, settings$markers$main_start, settings$markers$main_end,
    sprintf("source(here::here(\"%s\", \"%s\"))", paths$scripts, scripts))

  notes <- unlist(lapply(steps, function(s) s$notes), recursive = FALSE)
  other <- Filter(function(n) identical(n$kind, "other_package") && nzchar(n$package), notes)
  other_packages <- unique(unlist(lapply(other, function(n) n$package)))
  deps_block <- update_dependencies_file(paths$dependencies, installed$clients, installed$servers, other_packages, catalogue, settings, texts)

  damaged <- c(paths$main, paths$dependencies)[c(main_block, deps_block) == "damaged"]
  vapply(damaged, function(p) fill_template(texts$notes$block_damaged, list(PATH = p)), character(1), USE.NAMES = FALSE)
}
