# Builds the DSLite login/connection preamble for a NEW client-side test
# (setup.R, or setup-dslite.R next to an existing setup.R). Uses DSLite's own built-in
# canned datasets (config/dslite-canned-datasets.yml lists the options) —
# no external server, no credentials, no per-package config needed.
#
# Verified against a real run. No assignMethod() call is needed: the
# DSLite server's method table comes from defaultDSConfiguration(), which
# scans every INSTALLED package for an inst/DATASHIELD file — i.e. the
# server-side package (e.g. dsTidyverse provides arrangeDS), not the client
# package. The `packages` argument is only a requireNamespace() check. So
# the server package must be installed wherever the tests run (in CI: via
# the client's DESCRIPTION, e.g. Suggests, picked up by `needs: check`).
build_dslite_test_snippet <- function(dataset_choice, package_name) {
  paste(
    "require('DSLite')",
    "require('DSI')",
    sprintf("require('%s')", package_name),
    "",
    sprintf(
      "logindata <- DSLite::%s(packages = c(\"%s\"))",
      dataset_choice$setup_function, package_name
    ),
    "conns <- DSI::datashield.login(logins = logindata, assign = TRUE)",
    sep = "\n"
  )
}
