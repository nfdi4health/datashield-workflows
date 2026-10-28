# The bots' tunable rules from config/suggestion-policy.yml (reasons,
# thresholds, author roles, routing), with a project's own copy merged
# over it (read_config_yaml()).
suggestion_policy <- function() {
  read_config_yaml("config/suggestion-policy.yml")
}
