# A fresh Anthropic access token, for a run that outlived the one the
# anthropic-token action got at the start of the job (the API answers
# "OAuth access token has expired"). Same exchange as that action: a new
# GitHub OIDC token (ACTIONS_ID_TOKEN_REQUEST_URL / _TOKEN, there because
# the job has `id-token: write`), swapped at Anthropic using the
# federation rule (ANTHROPIC_ORG_ID, ANTHROPIC_SERVICE_ACCOUNT_ID,
# ANTHROPIC_FEDERATION_RULE_ID, set on the R step by the workflow).
# Returns the token, or NULL with a message if it can't be renewed. The
# token is never printed.
refresh_anthropic_token <- function() {
  env <- Sys.getenv(c("ACTIONS_ID_TOKEN_REQUEST_URL", "ACTIONS_ID_TOKEN_REQUEST_TOKEN",
                      "ANTHROPIC_ORG_ID", "ANTHROPIC_SERVICE_ACCOUNT_ID", "ANTHROPIC_FEDERATION_RULE_ID"))
  if (!all(nzchar(env))) {
    message("The Anthropic token expired and can't be renewed here (missing: ",
            paste(names(env)[!nzchar(env)], collapse = ", "), ").")
    return(NULL)
  }

  token <- tryCatch({
    oidc <- request(paste0(env[["ACTIONS_ID_TOKEN_REQUEST_URL"]], "&audience=https://api.anthropic.com")) |>
      req_headers("Authorization" = paste("Bearer", env[["ACTIONS_ID_TOKEN_REQUEST_TOKEN"]])) |>
      req_perform() |>
      resp_body_json()
    exchange <- request("https://api.anthropic.com/v1/oauth/token") |>
      req_body_json(list(grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                         assertion = oidc$value,
                         federation_rule_id = env[["ANTHROPIC_FEDERATION_RULE_ID"]],
                         organization_id = env[["ANTHROPIC_ORG_ID"]],
                         service_account_id = env[["ANTHROPIC_SERVICE_ACCOUNT_ID"]])) |>
      req_perform() |>
      resp_body_json()
    exchange$access_token
  }, error = function(e) {
    message("Renewing the Anthropic token failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(token) || !nzchar(token)) {
    return(NULL)
  }
  message("The Anthropic token expired during the run; renewed it.")
  token
}
