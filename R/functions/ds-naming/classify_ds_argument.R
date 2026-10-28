# Infers what one argument is from its name, default and documentation:
# a role (connection, new_object, output_type, checks, method, seed,
# column, object, value, plumbing, dots, unknown), for objects their class
# (ds_object_class()), a confidence and the evidence used. Rules ported
# from the inventory prototype (dev-notes/datashield-naming/classify.py),
# ~75-80 % precise on spot checks; what stays "low" goes to Claude.
classify_ds_argument <- function(arg, default, doc) {
  doc <- gsub("[{}]", "", gsub("\\\\(code|link|strong|emph|item|bold|sQuote|dQuote)\\{", "", doc))
  low <- tolower(doc)
  default <- default %||% ""
  rx <- function(p, x, ic = TRUE) grepl(p, x, perl = TRUE, ignore.case = ic)
  out <- function(role, class = "", confidence = "high", evidence = "") list(role = role, class = class, confidence = confidence, evidence = evidence)

  newobj_name <- "^(new[._]?(df|data|tbl|var|col|obj)[._]?name|newobj|new\\.?obj|newobject|new\\.object|new\\.name|newname|new\\.var|newvar|output\\.?name|out\\.?name|outname|output|newobj\\.name|new_obj|newobj_name|output_name|new\\.col|new\\.df\\.name|name\\.new)$"
  newobj_doc <- "(name (of|for) the (new|output|created|resulting|generated|assigned)|(new|output|resulting) (object|variable|data ?frame|vector|table|tibble)|object (to be )?(created|assigned|generated|stored)|(created|assigned|stored|saved) (on|in) the (data )?servers?|newobj)"
  choice_doc <- "can be set as|one of the allowable|one of (the following|\")|either \"|\"[^\"]+\",? (or|and) \"|'[^']+',? or '"
  num_doc <- "hyper-?parameter|\\blambda\\b|threshold|\\bnumber of\\b|percentage|proportion|tolerance|iterations?|maximum|minimum|\\bsize\\b|degrees of freedom|confidence level|\\balpha\\b"
  doc_class <- ds_object_class(doc)

  if (arg == "...") {
    return(out("dots", evidence = "dots"))
  }
  if (rx("^(datasources?\\w*|conns?|connections?|ds\\.?conns?|opals?)$", arg) || rx("DSConnection|opal connection|login object", doc, FALSE)) {
    return(out("connection", evidence = "name/doc"))
  }
  if ((arg == "type" && rx("split|combin", paste(low, tolower(default)))) || (rx("\\bsplit\\b", low) && rx("combine", low))) {
    return(out("output_type", evidence = "split/combine"))
  }
  if (rx("check", arg)) {
    return(out("checks", evidence = "name"))
  }
  # by documentation only when it is about a name (not "a logical ... output object")
  if (rx(newobj_name, arg) || (rx(newobj_doc, doc) && !rx("^logical", low) && rx("\\bname\\b", low) && !default %in% c("TRUE", "FALSE"))) {
    # Recognised by its name: high confidence; only by its documentation: medium.
    if (rx(newobj_name, arg)) {
      return(out("new_object", doc_class$class, "high", "name"))
    }
    return(out("new_object", doc_class$class, "medium", "doc"))
  }
  if (rx("session|handle|cursor|manifest|_json$|operation_id|request_|chunk|symbol|token|nonce|sha256|batch_", arg)) {
    return(out("plumbing", confidence = "medium", evidence = "name"))
  }
  if (rx(choice_doc, doc) && (!nzchar(doc_class$class) || !rx("names? of", low))) {
    return(out("method", confidence = "medium", evidence = "doc lists options"))
  }
  if (tolower(arg) %in% c("method", "methods", "algorithm", "option", "options", "approach", "test", "test.type", "method.type",
                          "alternative", "family", "link", "distribution", "metric", "mode", "how") ||
      rx("^c\\(\"[^\"]+\"\\s*,", default, FALSE)) {
    return(out("method", confidence = "medium", evidence = "name/default"))
  }
  if (default %in% c("TRUE", "FALSE", "T", "F") || rx("^(a |an )?(boolean|logical|if true|if false)", low)) {
    return(out("value", "logical", evidence = "default/doc"))
  }
  if (rx("seed", arg)) {
    return(out("seed", evidence = "name"))
  }
  if (rx("^(a |an |the )?(single |scalar |positive |non-negative )?(numeric value|integer|number of|length of|real number|numeric scalar|numerical value)", low)) {
    return(out("value", "numeric", evidence = "doc"))
  }
  # a string naming a column inside a data frame, not an object of its own
  if (rx(paste0("column names?|names? of (the |a )?(columns?|variables?) (in|of|within|that|holding|containing)|variable names?|",
                "denoting the column|name of the (outcome|exposure|mediator|treatment|id|time|status|event|grouping|strata) (variable|column)|",
                "columns? (to|by) (be )?(select|sort|group|use)|column(\\(s\\)|s)? in (the )?(input )?data ?frame"), low)) {
    return(out("column", confidence = "medium", evidence = "doc"))
  }
  if (rx("^(a |an )?numeric\\b(?! (or factor )?(vector|variable))", low)) {
    return(out("value", "numeric", "medium", "doc"))
  }
  # values sent along rather than server objects (seen in dsBaseClient
  # 7.0: incomparables, force.nfilter, exclude)
  if (rx("^(the |a |an )?values?\\b", low)) {
    return(out("value", confidence = "medium", evidence = "doc"))
  }
  if (rx("must be (specified as )?(a |an )?(positive |non-negative )?(integer|number)|\\bpositive integer\\b", low)) {
    return(out("value", "numeric", "medium", "doc"))
  }
  if (rx("passed (through |on )?to .{0,60}\\b(native|base) r\\b|\\bin (native|base) r\\b", low) && !rx("name of (the )?(input )?(object|data ?frame|vector)", low)) {
    return(out("value", confidence = "medium", evidence = "doc: passed to R"))
  }
  if (nzchar(doc_class$class)) {
    # vectors of values sent from the client ("vector of initial values")
    # are values, not server objects
    if (doc_class$class == "vector" && !rx("\\bnames?\\b|variable|server|column|object|covariate", low)) {
      return(out("value", confidence = "medium", evidence = "doc"))
    }
    return(out("object", doc_class$class, doc_class$confidence, "doc"))
  }
  if (rx("name of (the |a |an )?(input |server-side )?object", low)) {
    return(out("object", "", "medium", "doc"))
  }
  if (rx(num_doc, doc)) {
    return(out("value", "numeric", "medium", "doc"))
  }
  if (rx("^-?[0-9.eE]+L?$", default, FALSE) || rx("^(a |an )?(numeric|integer|number|positive|non-negative|single number)", low)) {
    if (nzchar(doc)) {
      return(out("value", "numeric", "high", "default/doc"))
    }
    return(out("value", "numeric", "medium", "default/doc"))
  }
  # name only, no documentation to go by
  nm <- tolower(arg)
  guess <- if (rx("^(x|y|z|var|variable|vec|vector|x\\d|y\\d|var\\d|v\\d|input\\.var|input)$", nm)) {
    "vector"
  }
    else if (rx("^(df|data|dataframe|data\\.frame|df\\.name|dataset|table|data\\.name|df\\d|.*\\.df)$", nm)) {
      "data.frame"
    }
    else if (rx("^tbl", nm)) {
      "tibble"
    }
    else if (rx("^(mat|matrix|m)$", nm)) {
      "matrix"
    }
    else if (rx("^(formula|form|fml)$", nm)) {
      "formula"
    }
    else if (rx("^(model|mod|fit|glm\\.?obj)$", nm)) {
      "model"
    }
    else if (rx("^(resource|res)$", nm)) {
      "resource"
    }
    else {
      ""
    }
  if (nzchar(guess)) {
    return(out("object", guess, "low", "name only"))
  }
  if (startsWith(default, "\"") || startsWith(default, "'")) {
    return(out("value", "string", "low", "default"))
  }
  if (default %in% c("NULL", "")) {
    return(out("unknown", confidence = "low", evidence = "no doc"))
  }
  out("value", confidence = "low", evidence = "default")
}
