# The disclosure settings triage may name in a DataSHIELD idea's spec: the
# list at settings$disclosure$settings_path in settings$disclosure$settings_file
# (config/ds-package-rules.yml by default, the community's source of truth;
# the path is a setting, since that file may change). Empty when either is
# missing, which leaves the disclosure fields out of the triage.
read_disclosure_settings <- function(settings) {
  conf <- settings$disclosure
  if (is.null(conf$settings_file) || length(conf$settings_path) == 0) {
    return(character(0))
  }
  rules <- read_config_yaml(conf$settings_file, required = FALSE)
  for (key in unlist(conf$settings_path)) {
    if (!is.list(rules) || is.null(rules[[key]])) {
      return(character(0))
    }
    rules <- rules[[key]]
  }
  unique(as.character(unlist(rules)))
}
