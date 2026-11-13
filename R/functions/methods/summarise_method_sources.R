# The pilot's numbers: of the methods named in the methods sections, how
# many the abstract names too, overall and by role, and the methods most
# often named only in the methods section. `found` from
# ask_claude_for_method_sources(), `n_papers` the papers compared.
summarise_method_sources <- function(found, n_papers, top = 20) {
  in_section <- found[found$in_methods_section, ]
  share <- function(rows) if (nrow(rows) == 0) NA_real_ else mean(rows$in_abstract)
  only_section <- in_section[!in_section$in_abstract, ]
  counts <- sort(table(only_section$name), decreasing = TRUE)
  list(
    papers = n_papers,
    methods_in_sections = nrow(in_section),
    share_in_abstract = share(in_section),
    share_main = share(in_section[in_section$role == "main", ]),
    share_secondary = share(in_section[in_section$role == "secondary", ]),
    abstract_only = sum(found$in_abstract & !found$in_methods_section),
    only_in_section = utils::head(data.frame(method = names(counts), papers = as.integer(counts)), top)
  )
}
