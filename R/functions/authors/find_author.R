# Looks up a contributor among the DESCRIPTION authors. `index` is a sure
# match: an e-mail of theirs equals the entry's (GitHub noreply addresses
# ignored), or the names are equal ignoring case, accents, punctuation and
# word order. `possible` is an entry with the same family name and first
# initial ("F. Schwarz" vs "Florian Schwarz") — reported, never matched,
# since adding someone twice is worse than asking once.
find_author <- function(authors, name, emails = character(0)) {
  emails <- tolower(emails[!grepl("noreply", emails, fixed = TRUE)])
  target <- sort(name_tokens(name))
  parts <- split_person_name(name)
  given_initial <- substr(name_tokens(parts$given)[1], 1, 1)

  for (i in seq_along(authors)) {
    p <- authors[i]
    if (length(emails) > 0 && any(tolower(unlist(p$email)) %in% emails)) {
      return(list(index = i, possible = NA_integer_))
    }
    if (identical(sort(name_tokens(c(p$given, p$family))), target)) {
      return(list(index = i, possible = NA_integer_))
    }
  }

  if (!is.null(parts$family)) {
    for (i in seq_along(authors)) {
      p <- authors[i]
      if (is.null(p$family) || is.null(p$given)) {
        next
      }
      same_family <- identical(name_tokens(p$family), name_tokens(parts$family))
      same_initial <- identical(substr(name_tokens(p$given)[1], 1, 1), given_initial)
      if (same_family && same_initial) {
        return(list(index = NA_integer_, possible = i))
      }
    }
  }
  list(index = NA_integer_, possible = NA_integer_)
}
