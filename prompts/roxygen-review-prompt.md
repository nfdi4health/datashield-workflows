You are reviewing roxygen2 documentation for an R function for accuracy
and completeness. Give each field as plain prose or code, without `#'`
markers or `@tag` labels: a script assembles the block from your fields
in the right order, and keeps every tag you don't handle (`@export`,
`@import`, `@seealso`, …) exactly as it is.

Style requirements per field:
{{STYLE_GUIDANCE}}

{{ROLE_GUIDANCE}}

Existing roxygen block (to check against the code; a field you change
is written anew, not copied from here):
{{EXISTING_BLOCK}}

Function source:
{{FUNCTION_SOURCE}}

Function parameters, in order: {{PARAMS}}

First check every claim in the existing block against the function
source: defaults and what happens when an argument is left out, argument
types (e.g. a data frame vs. the *name* of a server-side data frame),
what is returned and in which shape, side effects. A claim the code
doesn't support is inaccurate, however small the wording fix.

For each field: if existing content is already accurate and meets the
guidance, leave it out of your answer — the script keeps the existing
text (do not reword something already correct). Treat placeholder or
lazy content (e.g. "XXXXX", "TODO", "tbd") and stale content (e.g. an
outdated example server) as inadequate and rewrite it. Return text only
for the fields you change, including a missing one you write from
scratch (a missing title, description or parameter must be written).

List every field you change in `changes`, with the reason that
honestly fits and a one-sentence explanation:
{{REASONS}}
Not every reason leads to a proposed change, so don't upgrade a clarity
or style change to a stronger reason — and don't downgrade a correction
of a false statement to clarity or style.

If the form has a `code_issues` field and, while checking, you notice
code that likely doesn't do what it is
meant to — a wrong formula, a path or object that doesn't match, a
return value that differs from what the function clearly intends — list
it in `code_issues`. Document the code's actual behavior, but don't
silently document around a defect. Only real defects, not style or
refactoring wishes; an empty list is the normal case. For each, reason
it through in `explanation` first — what the code actually does, keeping
R's scoping and evaluation rules in mind — and only then give your
verdict, how confident you are, and the one-line summary. If the
reasoning shows it isn't a defect after all, say so in the verdict;
don't report it anyway.

Earlier findings of this bot on this function, from its open suggestion
PR. Changes it already proposed are part of the existing block above;
these are the suggestions it did not apply and the possible bugs it
reported:
{{EARLIER_FINDINGS}}

If there are earlier findings: judge each in `earlier_findings` —
still valid, superseded (no longer correct, e.g. the code changed, or it
was wrong) or resolved (the code or documentation now does it). When a
change or code issue of yours says the same as an earlier finding, also
in other words, give its id in `repeats_earlier`.
