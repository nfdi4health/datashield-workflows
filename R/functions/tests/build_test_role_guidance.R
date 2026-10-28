# Builds the testing-strategy guidance folded into the test-generation
# prompt — a genuinely different STRATEGY per role, not just wording (see
# "DataSHIELD client packages: DSLite" in dev-notes/test-suggest.md).
# `guidance` is config/test-role-guidance.yml. uses_connections says
# whether this function works on DataSHIELD connections
# (uses_ds_connections()): client functions always use DSLite, utility
# functions only when they use connections, otherwise they get local
# file-system guidance. dslite_datasets is the
# config/dslite-canned-datasets.yml$datasets list, only needed when a
# fresh DSLite setup will be generated: Claude picks one via the dslite_dataset
# tool field, this function just presents the options.
build_test_role_guidance <- function(datashield, ds_type, has_existing_setup, dslite_datasets, guidance, uses_connections = FALSE) {
  join <- function(x) paste(unlist(x), collapse = " ")

  if (isTRUE(datashield) && identical(ds_type, "utility") && !isTRUE(uses_connections)) {
    return(join(guidance$utility_local))
  }
  if (!isTRUE(datashield) || !ds_type %in% c("client", "utility")) {
    return(join(guidance$default))
  }
  if (isTRUE(has_existing_setup)) {
    return(join(guidance$client_existing_setup))
  }

  dataset_lines <- vapply(dslite_datasets, function(d) {
    sprintf("- %s: %s Fits when: %s", d$name, d$description, d$fits_when)
  }, character(1))

  paste(
    join(guidance$client_new_setup$intro),
    "",
    paste(dataset_lines, collapse = "\n"),
    "",
    join(guidance$client_new_setup$outro),
    sep = "\n"
  )
}
