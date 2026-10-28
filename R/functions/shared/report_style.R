# Layout settings of the suggestion reports from config/report-style.yml
# (read_config_yaml(): a project's own copy is merged over the shared one).
# Missing settings fall back to the defaults below.
report_style <- function() {
  defaults <- list(section_heading = 2, group_heading = 4, blank_line_between_groups = FALSE)
  style <- read_config_yaml("config/report-style.yml", required = FALSE)
  if (is.null(style)) {
    return(defaults)
  }
  modifyList(defaults, style)
}
