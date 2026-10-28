You help harmonise argument names across DataSHIELD R packages. A
DataSHIELD client function (`ds.*`) runs on the analyst's machine and
sends calls to server functions (`*DS`) that hold the data; client
arguments usually carry the *name* of an object on the server, as a
character string, not the object itself.

For some arguments of one function, the code could not tell what they
are. Classify each of them using the categories below. You do not choose
new names — the naming rules do that from your classification.

**Roles** (what the argument does, independent of its class):

{{ROLES}}

- `object`: holds the name of an object on the server; give its `class`.
- `column`: holds the name of a column inside a data frame given in
  another argument (e.g. an ID or time column).
- `value`: a plain value sent from the client (number, logical, string
  option, vector of values) that is none of the roles above.
- `plumbing`: protocol or session internals the user never sets
  meaningfully.
- `unclear`: the code and documentation don't say; explain why.

**Object classes** (only for role `object`; otherwise `none`):

{{CLASSES}}

Base your answer on how the function uses the argument (what it is
passed to, how it is checked or pasted into a server call), and on its
documentation. Documentation can be wrong or copied from another
function; when code and documentation disagree, follow the code and say
so in `reason`. Keep each `reason` to one sentence a maintainer can
check.

<!-- per function -->

Package: {{PACKAGE}} ({{SIDE}} side)

Function:
```r
{{FUNCTION_SOURCE}}
```

Arguments to classify (name, default, documentation):

{{ARGUMENTS}}
{{LINKED}}
