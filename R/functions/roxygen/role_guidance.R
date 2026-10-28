# Builds the DataSHIELD role-specific guidance text (client/server/utility)
# folded into the review prompt. demo_snippet is the canonical multi-study
# login example from build_demo_login_snippet(), or NULL when the package
# has no matching study group or (utility) the function doesn't use
# DataSHIELD connections — in which case no example guidance is added.
role_guidance <- function(datashield, ds_type, role_guidance_config, demo_snippet) {
  if (!isTRUE(datashield)) {
    return("")
  }

  if (ds_type %in% c("client", "utility")) {
    cfg <- role_guidance_config[[ds_type]]
    text <- build_role_guidance_text(cfg)
    if (!is.null(demo_snippet)) {
      demo_intro <- paste(unlist(cfg$demo_environment), collapse = " ")
      text <- paste(text, "", demo_intro, "", demo_snippet, sep = "\n")
    }
    text
  } else if (identical(ds_type, "server")) {
    build_role_guidance_text(role_guidance_config$server)
  } else {
    ""
  }
}
