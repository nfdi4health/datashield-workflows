# Whether a function that needs DataSHIELD connections gets a fresh DSLite
# test setup, following the dslite-setup input:
# - "auto": only if the tests show no approach to connecting at all;
# - "create": unless the tests already use DSLite (e.g. during a switch
#   from Opal to DSLite);
# - "never": never.
# Returns "create" (generate a setup), "reuse" (follow how the existing
# tests connect) or "none" (nothing to connect with: the function is
# reported, not tested). `approaches` comes from
# detect_connection_approaches().
decide_dslite_setup <- function(mode, approaches) {
  create <- switch(mode,
    auto = length(approaches) == 0,
    create = !"DSLite" %in% approaches,
    never = FALSE
  )
  if (create) {
    "create"
  } else if (length(approaches) > 0) {
    "reuse"
  } else {
    "none"
  }
}
