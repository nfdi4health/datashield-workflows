# Credits one PR contributor in DESCRIPTION (`d`, a desc object, changed
# in place): `roles$changed_r_code` (aut) if they changed files under R/,
# `roles$otherwise` (ctb) otherwise — authors$roles of
# config/suggestion-policy.yml. Adds new people with the name split into
# given and family, and upgrades an existing entry to the first role
# (dropping the second); never downgrades or removes anyone and leaves
# other roles (cre, cph, ...) alone. A possible but uncertain match is
# only reported. Returns list(changed, line) — the line for the report —
# or NULL if there is nothing to say.
credit_contributor <- function(d, name, r_files, emails, roles = suggestion_policy()$authors$roles) {
  upper <- roles$changed_r_code
  lower <- roles$otherwise
  role <- if (length(r_files) > 0) {
    upper
  } else {
    lower
  }
  reason <- if (length(r_files) > 0) {
    shown <- paste0("`", utils::head(r_files, 3), "`", collapse = ", ")
    more <- if (length(r_files) > 3) {
      sprintf(" and %d more", length(r_files) - 3)
    } else {
      ""
    }
    sprintf("changed %s%s", shown, more)
  } else {
    "no changes under `R/`"
  }

  authors <- d$get_authors()
  match <- find_author(authors, name, emails)

  if (is.na(match$index)) {
    if (!is.na(match$possible)) {
      listed <- format(authors[match$possible], include = c("given", "family"))
      return(list(changed = FALSE, line = sprintf(
        "- **%s**: not added — may already be listed as %s. If it's someone else, add them by hand (`%s`, %s).",
        name, listed, role, reason
      )))
    }
    parts <- split_person_name(name)
    d$add_author(given = parts$given, family = parts$family, role = role)
    check <- if (is.null(parts$family)) {
      " Only one name part is known — please check the name."
    } else {
      ""
    }
    return(list(changed = TRUE, line = sprintf("- **%s**: added as `%s` (%s).%s", name, role, reason, check)))
  }

  person <- authors[match$index]
  current <- unlist(person$role)
  if (role == upper && !upper %in% current) {
    d$add_role(upper, given = person$given, family = person$family)
    if (lower %in% current) {
      d$del_role(lower, given = person$given, family = person$family)
    }
    new_roles <- setdiff(c(current, upper), lower)
    return(list(changed = TRUE, line = sprintf(
      "- **%s**: `%s` → `%s` (%s).", name, paste(current, collapse = ", "), paste(new_roles, collapse = ", "), reason
    )))
  }
  NULL
}
