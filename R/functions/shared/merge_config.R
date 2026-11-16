# Merges a project's config (`own`) over the shared defaults, as
# read_config_yaml() does. Named lists (YAML mappings) merge key by key,
# recursively; a key set to null (`key: ~`) in `own` removes it. Anything
# else in `own` replaces the default as a whole: values, vectors (YAML
# sequences of scalars) and unnamed lists (YAML sequences of mappings,
# e.g. `study_groups:` in config/datashield-example-env.yml), also an
# empty one (`[]`). utils::modifyList() isn't used: it drops the unnamed
# elements of `own` when the default is a list too, so a project's list of
# mappings was ignored.
merge_config <- function(defaults, own) {
  is_mapping <- function(x) is.list(x) && !is.null(names(x))
  if (!is_mapping(defaults) || !is_mapping(own)) {
    return(own)
  }
  for (key in names(own)) {
    if (is.null(own[[key]])) {
      defaults[key] <- NULL
    } else {
      defaults[[key]] <- merge_config(defaults[[key]], own[[key]])
    }
  }
  defaults
}
