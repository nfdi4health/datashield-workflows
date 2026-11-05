# The name the rules give one argument, from its role and class
# (classify_ds_argument(), or Claude's classification): exceptions and R
# conventions keep their name; roles and object classes get the canonical
# name; columns and plain values only the general style
# (to_naming_style()). Returns list(proposed, rule, rule_open, match,
# reason); `proposed` is NA when nothing can be said (role unknown, object
# of unknown class) — those go to Claude or stay unresolved. `match`:
# canonical (already right), alias (a known variant), rule (renamed by the
# rule), style (spelling only), exception, none.
propose_ds_name <- function(arg, role, class, package, rules) {
  sep <- rule_name(rules$style$separator)
  result <- function(proposed, rule, open = FALSE, aliases = character(0), reason = "") {
    match <- if (is.na(proposed)) {
      "none"
    } else if (identical(proposed, arg)) {
      "canonical"
    } else if (arg %in% aliases) {
      "alias"
    } else {
      "rule"
    }
    list(proposed = proposed, rule = rule, rule_open = open || sep$open && !identical(proposed, arg) && grepl("[._]", proposed),
         match = match, reason = reason)
  }
  keep <- function(rule, reason) list(proposed = arg, rule = rule, rule_open = FALSE, match = "exception", reason = reason)

  if (package %in% names(rules$exceptions$packages)) {
    return(keep("exceptions.packages", rules$exceptions$packages[[package]]$reason))
  }
  if (arg == "...") {
    return(keep("style.allowed_r_conventions", "dots"))
  }
  if (arg %in% unlist(rules$style$allowed_r_conventions)) {
    return(keep("style.allowed_r_conventions", "R convention"))
  }

  role_rule <- c(connection = "connection", new_object = "new_object", output_type = "output_type", checks = "checks", method = "method", seed = "seed")
  if (role %in% names(role_rule)) {
    r <- rules$roles[[role_rule[[role]]]]
    if (role == "method" && arg %in% unlist(r$exceptions)) {
      return(keep("roles.method.exceptions", "distinct meaning"))
    }
    n <- rule_name(r$name)
    return(result(n$name, paste0("roles.", role_rule[[role]]), n$open, unlist(r$aliases)))
  }
  if (role == "object") {
    if (!nzchar(class %||% "") || is.null(rules$classes[[class]])) {
      return(result(NA, "classes", reason = "object of unknown class"))
    }
    r <- rules$classes[[class]]
    n <- rule_name(r$name)
    return(result(n$name, paste0("classes.", class), n$open, unlist(r$aliases)))
  }
  if (role %in% c("column", "value", "plumbing")) {
    styled <- to_naming_style(arg, sep$name, rules$style$case)
    r <- result(styled, "style")
    if (!identical(styled, arg)) {
      r$match <- "style"
    }
    return(r)
  }
  result(NA, "unresolved", reason = "role unknown")
}
