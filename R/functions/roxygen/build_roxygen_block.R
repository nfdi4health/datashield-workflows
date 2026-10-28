# Deterministic assembly: the ONLY place the final roxygen block is built,
# in the order given by tag_order. Only the tags in `managed` come from
# Claude's fields — and of those only the `accepted` ones (see
# accepted_roxygen_fields()); a managed field that wasn't accepted keeps
# its original lines. Every other tag in the original block (@export,
# @author, @seealso, @rdname, ... — including ones nobody anticipated) is
# carried forward verbatim with all its lines, so nothing a package author
# wrote is ever silently dropped. Tags not named in tag_order go where its
# "*" entry is (appended at the end if there is none), in original order.
build_roxygen_block <- function(result, parsed, path, accepted) {
  managed <- c("title", "description", "details", "param", "return", "examples")
  order <- unlist(style$tag_order)
  if (!"*" %in% order) {
    order <- c(order, "*")
  }
  carried <- Filter(function(ch) !ch$tag %in% managed, parsed$tag_chunks)
  carried_lines <- function(keep) unlist(lapply(Filter(keep, carried), `[[`, "lines"), use.names = FALSE)
  sections <- list()

  wrap <- function(text) {
    paste0("#' ", strsplit(text, "\n")[[1]])
  }
  clean <- function(text, field_name) {
    strip_artifact_lines(text, "^\\s*(#'|@[A-Za-z]+\\b)", "roxygen syntax (comment markers or tag labels)", field_name, path)
  }
  required_text <- function(text, field_name) {
    text <- clean(text, field_name)
    if (!nzchar(trimws(text))) {
      stop(sprintf("%s: '%s' field was empty after sanitization — Claude's response likely contained only roxygen artifacts.", path, field_name))
    }
    text
  }

  # Required fields: Claude's text if accepted or if there is nothing to
  # keep; otherwise the original lines.
  required_field <- function(key, tag, field_name) {
    original <- original_roxygen_field(parsed, key)
    if (key %in% accepted || is.null(original)) {
      wrap(paste0("@", tag, " ", required_text(roxygen_field_text(result, key), field_name)))
    } else {
      original$lines
    }
  }
  # Optional fields: never added unless accepted.
  optional_field <- function(key, new_lines) {
    if (key %in% accepted) {
      return(new_lines)
    }
    original_roxygen_field(parsed, key)$lines
  }

  for (tag in order) {
    if (tag == "*") {
      sections[["*"]] <- carried_lines(function(ch) !ch$tag %in% order)
    } else if (!tag %in% managed) {
      sections[[tag]] <- carried_lines(function(ch) ch$tag == tag)
    } else if (tag == "title") {
      sections[["title"]] <- required_field("title", "title", "title")
    } else if (tag == "description") {
      sections[["description"]] <- required_field("description", "description", "description")
    } else if (tag == "details") {
      details <- clean(result$details, "details")
      details_lines <- NULL
      if (nzchar(trimws(details))) {
        details_lines <- wrap(paste0("@details ", details))
      }
      sections[["details"]] <- optional_field("details", details_lines)
    } else if (tag == "param") {
      param_lines <- character(0)
      for (p in parsed$params) {
        if (is.null(result$params[[p]]) && paste0("param:", p) %in% accepted) {
          stop(sprintf("Claude's response is missing documentation for parameter '%s'.", p))
        }
        param_lines <- c(param_lines, required_field(paste0("param:", p), paste("param", p), sprintf("param.%s", p)))
      }
      sections[["param"]] <- param_lines
    } else if (tag == "return") {
      sections[["return"]] <- required_field("return", "return", "return_doc")
    } else if (tag == "examples") {
      examples_body <- clean(result$examples_body, "examples_body")
      examples_lines <- NULL
      if (nzchar(trimws(examples_body))) {
        examples_lines <- c(
          "#' @examples",
          "#' \\dontrun{",
          paste0("#' ", strsplit(examples_body, "\n")[[1]]),
          "#' }"
        )
      }
      sections[["examples"]] <- optional_field("examples", examples_lines)
    }
  }

  paste(unlist(sections, use.names = FALSE), collapse = "\n")
}
