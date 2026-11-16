# The pilot's numbers: of the methods named in the methods sections, how
# many the abstract names too, overall and by role, and the methods most
# often named only in the methods section, and the variants named most
# often (method and variant, in how many papers; only those named in at
# least `min_variant_papers` papers). `found` from
# ask_claude_for_method_sources(), `n_papers` the papers compared.
summarise_method_sources <- function(found, n_papers, top = 20, min_variant_papers = 1) {
  if (is.null(found$variant)) found$variant <- rep("", nrow(found))
  in_section <- found[found$in_methods_section, ]
  share <- function(rows) if (nrow(rows) == 0) NA_real_ else mean(rows$in_abstract)
  only_section <- in_section[!in_section$in_abstract, ]
  counts <- sort(table(only_section$name), decreasing = TRUE)
  variants <- unique(found[nzchar(found$variant), c("id", "name", "variant")])
  variant_counts <- if (nrow(variants) == 0) {
    data.frame(method = character(0), variant = character(0), papers = integer(0))
  } else {
    v <- stats::aggregate(id ~ name + variant, data = variants, FUN = length)
    v <- v[v$id >= min_variant_papers, , drop = FALSE]
    v <- v[order(-v$id, v$name, v$variant), , drop = FALSE]
    data.frame(method = v$name, variant = v$variant, papers = as.integer(v$id))
  }
  list(
    papers = n_papers,
    methods_in_sections = nrow(in_section),
    share_in_abstract = share(in_section),
    share_main = share(in_section[in_section$role == "main", ]),
    share_secondary = share(in_section[in_section$role == "secondary", ]),
    abstract_only = sum(found$in_abstract & !found$in_methods_section),
    only_in_section = utils::head(data.frame(method = names(counts), papers = as.integer(counts)), top),
    variants = utils::head(variant_counts, top)
  )
}
