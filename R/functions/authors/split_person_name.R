# Splits a full name into given and family name for person(): the last
# word is the family name, together with name particles right before it
# ("Ludwig van Beethoven" -> "Ludwig" / "van Beethoven"). A one-word name
# can't be split and comes back as given name only (family NULL). The
# particles are authors$family_name_particles of config/suggestion-policy.yml.
split_person_name <- function(name, particles = unlist(suggestion_policy()$authors$family_name_particles)) {
  words <- strsplit(trimws(name), "\\s+")[[1]]
  if (length(words) < 2) {
    return(list(given = trimws(name), family = NULL))
  }

  start <- length(words)
  while (start > 2 && tolower(words[start - 1]) %in% particles) {
    start <- start - 1
  }

  list(
    given = paste(words[seq_len(start - 1)], collapse = " "),
    family = paste(words[start:length(words)], collapse = " ")
  )
}
