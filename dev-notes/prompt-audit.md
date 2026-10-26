# Prompt and context audit (J, step 1) — 2026-10-16

**Decided 2026-10-19 (user): all six hunks accepted.** A, C, D, E, F
applied on `v1/foundation` the same day, B after C and D:
`excluded_functions` is a map name → reason (a project allows one again
with `name: ~`), written into the prompt by `format_excluded_functions()`.
Tests pass; not yet compared in the CI test round. Flags 7–9 unchanged.

Originally a report only: nothing here was applied. The hunks at the end are
proposals to take or leave one by one; each prompt change should be
checked in the CI test round (`dev-notes/ci-test-round.md`) before and
after, since prompts are per-model artifacts.

**Scope (assumed):** what the bots send to Claude — `prompts/*.md`, the
guidance files R writes into them (`config/roxygen-style.json`,
`config/test-role-guidance.json`, `config/datashield-role-guidance.json`,
`config/analysis-suggest.yml` exclusions), the tool schemas
(`R/functions/*/build_*_tool.R`) and the request settings
(`config/claude.yml`, `call_claude_tool()`). Not in scope: `CLAUDE.md`
and the dev-notes (read by the coding agent, not the bots).

**Target models (assumed):** per profile as configured — roxygen review
and naming classification on Claude Sonnet 5 (thinking off); test review,
failure classification and analysis on Claude Opus 5 (adaptive thinking,
effort high). Claude Opus 5.5 is the documented next step for the test
profiles (`tool_choice_type: auto`, already built), so findings that
matter for it are marked.

## Summary

The surface is in good shape: structure is enforced by schemas and R
(enums, assembly in R, R-side caps and filters), safety rules carry
their reasons, and the per-function / shared split for caching is in
place. Three findings are worth acting on:

1. **A stale fact in a tool description** — the test tool still tells
   Claude that new tests go into `test-<category>-<function>.R`; files
   are named after the R file since 2026-10-02.
2. **The `ds.glmSLMA` / forest-plot rule lives in two places** — prose
   in the analysis prompt and `excluded_functions` in the config (the
   case that started J).
3. **Reasoning-first fields** in the failure classification ("reason it
   through in `explanation` first") — redundant with adaptive thinking,
   and on Opus 5 / 5.5 instructing reasoning into the output can be
   declined as reasoning extraction (not retried on the fallback).

Counts: Group 1 (prompt text) 4 findings + 3 flags; Group 2 (instruction
files) not applicable; Group 3 (tool descriptions) 2; Group 4 (request
config and architecture) 0 — model calls are all judgment steps, R
already pre-classifies obvious failures, usage is logged per call, and
the cache prefix holds only stable content.

## Findings

| # | Location | Evidence | Pattern | Why it doesn't fit | Conf. | Action |
|---|---|---|---|---|---|---|
| 1 | `R/functions/tests/build_submit_tests_tool.R:60` | "the script writes the test into test-<category>-<function>.R" | 2 — volatile specifics / stale fact | `place_new_tests()` writes `test_file_path(name, category)` with `name` = the R file's name (`test_file_name()`); the prompt's own scheme text says the same. The description contradicts both. | High | rewrite (hunk A) |
| 2 | `prompts/analysis-script-prompt.md:46-51` vs `config/analysis-suggest.yml:86` | "Study-level meta-analysis (ds.glmSLMA) and forest plots aren't available in the test environment…" / `excluded_functions: [datashield.login, datashield.logout, ds.glmSLMA, ds.forestplot]` | 1c padding / 2 "information in one place" | The same rule is kept in prose and in config; a project that changes the config (e.g. a test environment with `ds.glmSLMA`) still gets the prose. | High | move: exclusions only in config, each with a reason, written into the prompt by R (hunk B; needs a config shape change — part of C) |
| 3 | `prompts/test-failure-classification-prompt.md:16-17`, tool `explanation` | "For each failure, reason it through in `explanation` first, then give the category" | 1b — required reasoning in tool input | The profile runs with adaptive thinking; the ordering instruction duplicates it, and on Opus 5 / 5.5 instructing reasoning into the output may be declined as `reasoning_extraction` (not retried on a fallback). A short justification for the report stays useful. | Medium | rewrite (hunk C) |
| 4 | `prompts/roxygen-review-prompt.md:1-6, 13-19, 77-79` | "You do NOT write roxygen syntax…", "DO NOT COPY OR ECHO THIS BACK. If any field … that is an error", "Do not include export or import directives anywhere…" | 1a pressure language; 1c repetition | One constraint stated three times, twice in caps. R enforces it (`strip_artifact_lines()`, carried tags in `build_roxygen_block()`), so the prose only has to state the contract once, plainly. | Medium | rewrite (hunk D) |
| 5 | `prompts/roxygen-review-prompt.md:81-82`, `test-review-prompt.md:123-124`, `test-failure-classification-prompt.md:22-23`, `ds-naming-classification-prompt.md:35-36` | "Call the submit_… tool with your result. Do not write any prose response — only call the tool." | 3 — tool names in prompt prose; 1b forced-tool scaffolding | With `tool_choice` forced the line does nothing; in `auto` mode (Opus 5.5) `call_claude_tool()` already appends the instruction with the configured tool name, so the prompt repeats it with a hard-coded name that `tool_name` in `config/claude.yml` can change. "One entry per listed failure" is contract and belongs in the tool's `failures` description. | Medium | remove (hunk E) |
| 6 | `config/test-role-guidance.json:14-17, 33-35` | "do NOT write your own login code, and do NOT assume data beyond…", "do NOT write your own login/connection code" | 1a pressure language | A real constraint, but in caps without its reason; current models follow the plain statement, and the reason (the setup already connects; a second login breaks the session) helps more than volume. | Medium | rewrite (hunk F) |
| 7 | `R/functions/roxygen/build_submit_review_tool.R:80`, `roxygen-review-prompt.md:58-63` | "First reason it through … Write this before deciding." | 1b — required reasoning in tool input | On this profile (Sonnet 5, thinking **off**) the field is the substitute for thinking, added after wrong bugs on dsSurvivalClient PR #37. It becomes redundant (and a refusal risk) only if thinking is turned on — the step CLAUDE.md already names if wrong bugs persist. | Low | flag — revisit together with thinking for roxygen |
| 8 | `config/roxygen-style.json` | "Max 10 words", "Max 2 lines", "1-2 sentences", "Up to 4 lines" | 1f numeric ceilings (grep match) | These shape the *documentation* (the package's house style), not Claude's reply length. Kept. | Low | flag — no change |
| 9 | `prompts/analysis-script-prompt.md:39-45`, `analysis-repair-prompt.md:6-8` | "`ALONG.WITH.name` belongs to `ds.seq`, not `ds.rep`", "use `ds.make()` or `ds.vectorCalc()` … not `ds.rep()`", "don't guess another argument" | 1d patch accretion | Each line traces to one failed run. The general rule is enforced in R (calls checked against the installed functions, one repair round), the `ds.rep` advice is DataSHIELD knowledge Claude lacks. Re-test removing only the `ALONG.WITH.name` example once the stepwise analysis has run in CI. | Low | flag |

Checked and kept (no finding): the safety rules with reasons — "Never
adjust a test to match output that may be wrong — that would hide the
bug", no `try()` / `suppressWarnings()` around the code under test,
"Never log in or out, and never load login files", disclosure control,
"never guess or fabricate" a server function name (real failure:
invented names); the reason definitions shared by prompt and enum
descriptions (working redundancy); the role lines at the top of each
prompt; the `<!-- per function -->` / `<!-- per request -->` cache
splits.

## Proposed hunks

### A — test file category (finding 1)

```diff
--- a/R/functions/tests/build_submit_tests_tool.R
+++ b/R/functions/tests/build_submit_tests_tool.R
@@ -60 +60 @@
-      description = "The test file category this test belongs to (see the categories in the prompt); the script writes the test into test-<category>-<function>.R."
+      description = "The test file category this test belongs to (see the categories in the prompt); the script writes the test into test-<category>-<R file>.R, <R file> being the function's file name without .R."
```

### B — exclusions only in config (finding 2)

Config (shape change; a project's own copy merges key by key, so the
map form also lets a project drop one exclusion):

```diff
--- a/config/analysis-suggest.yml
+++ b/config/analysis-suggest.yml
-excluded_functions: [datashield.login, datashield.logout, ds.glmSLMA, ds.forestplot]
+# Functions left out of the reference Claude gets, each with the reason
+# written into the prompt; a step that needs one gets a limitation note.
+excluded_functions:
+  datashield.login: the login has already run
+  datashield.logout: the login has already run
+  ds.glmSLMA: not available in the test environment; fit pooled models with ds.glm()
+  ds.forestplot: not available in the test environment
```

Prompt — the paragraph goes, a placeholder filled by R from the map
replaces it:

```diff
--- a/prompts/analysis-script-prompt.md
+++ b/prompts/analysis-script-prompt.md
@@ -46,6 +46,5 @@
-- Study-level meta-analysis (ds.glmSLMA) and forest plots aren't
-  available in the test environment. Fit models with ds.glm() on the
-  pooled data. If the plan asks for study-level estimates or a forest
-  plot, add a `limitation` note saying the step needs ds.glmSLMA and
-  ds.forestplot, which couldn't be tested here, instead of writing
-  that code.
+- Not available here, and why: {{EXCLUDED_FUNCTIONS}}. If a step needs
+  one of them, add a `limitation` note naming the function instead of
+  writing that code.
```

R: the reader of `excluded_functions` takes the names of the map (a
plain list still works, without reasons), and the prompt builder fills
`EXCLUDED_FUNCTIONS` as "`ds.glmSLMA` (not available in the test
environment; …), …".

### C — failure classification without reasoning-first (finding 3)

```diff
--- a/prompts/test-failure-classification-prompt.md
+++ b/prompts/test-failure-classification-prompt.md
@@ -16,5 +16,5 @@
-For each failure, reason it through in `explanation` first, then give
-the category and how confident you are. Choose real_bug only when the
+For each failure give the category, how confident you are, and a short
+explanation citing the failure output and the code. Choose real_bug only when the
 test's expectation is clearly what the function is meant to do; when the
 intended behaviour is unclear, say so with a lower confidence. Judge
 each failure on its own; several can share one cause.
--- a/R/functions/tests/build_submit_failure_classification_tool.R
+++ b/R/functions/tests/build_submit_failure_classification_tool.R
-              explanation = list(type = "string", description = "1-3 sentences reasoning it through first, referencing the actual failure output and the function's code."),
+              explanation = list(type = "string", description = "1-3 sentences why, citing the actual failure output and the function's code."),
```

(The field order — explanation before category — can stay; only the
instruction to reason in the output goes.)

### D — roxygen output contract, once and plainly (finding 4)

```diff
--- a/prompts/roxygen-review-prompt.md
+++ b/prompts/roxygen-review-prompt.md
@@ -1,6 +1,6 @@
 You are reviewing roxygen2 documentation for an R function for accuracy
-and completeness. You do NOT write roxygen syntax, comment markers, or
-tag labels — you only supply the prose content for each field below. A
-script assembles the final documentation from your fields, so there is
-no way for you to duplicate anything or get the tag order wrong; just
-answer each field once.
+and completeness. Give each field as plain prose or code, without `#'`
+markers or `@tag` labels: a script assembles the block from your fields
+in the right order, and keeps every tag you don't handle (`@export`,
+`@import`, `@seealso`, …) exactly as it is.
@@ -13,7 +13,4 @@
-Existing roxygen block (for context on current wording/accuracy only —
-DO NOT COPY OR ECHO THIS BACK. If any field in your answer contains
-text from this block — including its comment markers (#') or tag
-labels like @param, @return, @export, @import — that is an error. Every
-field must be your own new prose, written from scratch, with no
-roxygen syntax of any kind:
+Existing roxygen block (to check against the code; a field you change
+is written anew, not copied from here):
 {{EXISTING_BLOCK}}
@@ -77,3 +74,0 @@
-Do not include export or import directives anywhere in your answer —
-those are handled entirely outside this review and are not part of any
-field.
```

### E — no tool-calling line in the prompts (finding 5)

Remove the last paragraph of `roxygen-review-prompt.md`,
`test-review-prompt.md` and `ds-naming-classification-prompt.md`; in
`test-failure-classification-prompt.md` it goes too, and its contract
moves into the schema:

```diff
--- a/R/functions/tests/build_submit_failure_classification_tool.R
+++ b/R/functions/tests/build_submit_failure_classification_tool.R
         failures = list(
           type = "array",
+          description = "One entry per listed failure, in any order; `failure` names which.",
```

Check before removing: `call_claude_tool()` adds its instruction only in
`auto` mode; in forced mode nothing replaces the line, which is the
point (the API already forces the call). Grep for the sentence in tests
first (`test-shared-claude.R` asserts the auto-mode instruction, not
the prompt's).

### F — DataSHIELD test setup, plainly with the reason (finding 6)

```diff
--- a/config/test-role-guidance.json
+++ b/config/test-role-guidance.json
-    "defines, under the names it uses — do NOT write your own login code, and",
-    "do NOT assume data beyond what those files assign. Leave dslite_dataset",
+    "defines, under the names it uses. Don't add login code — the setup has",
+    "already connected, and a second login breaks that session — and use only",
+    "the data those files assign. Leave dslite_dataset",
@@
-    "it as \"D\" (and its columns as e.g. \"D$LAB_TSC\"), and do NOT write",
-    "your own login/connection code. Server-side methods are registered",
+    "it as \"D\" (and its columns as e.g. \"D$LAB_TSC\"); it has already",
+    "connected, so add no login code. Server-side methods are registered",
```

## Next (J step 2, with the user)

Take or drop the hunks; B depends on the config format decision (C/D of
the v1 plan). Run the CI test round once before and once after the
accepted prompt changes on dsSupportClient, one profile at a time, and
compare the reports (suggestions made, bugs reported, refusals). Re-run
this audit at the Opus 5.5 switch.

## Second pass (2026-10-26) — J closed

After hunks A–F ran in the CI test round on dsSupportClient (2026-10-21:
full reviews and a "changed" PR run of both bots, reports and proposals as
expected), a second look at what the first pass didn't cover:

- **Prompts** (`prompts/*.md`, all placeholders filled by R): no stale
  facts left (test file names, `accept_reasons`, sweep wording), no
  instructions the schema or R already enforce, safety rules with their
  reasons. The analysis exclusions come only from config (hunk B).
- **Special cases in R:** the remaining package names in code are domain
  logic, not workarounds — DSLite/DSOpal/Armadillo detection of how tests
  connect, and the analysis bot describing server objects with
  dsBaseClient when it is installed.
- **Context sizes:** capped since the cost pass (support files 20,000
  characters each within a budget, example test files cut, failure
  messages at 1,000 characters); the test prompt's shared part is cached.

Nothing further to change. Flags stay: 7 (reasoning field for possible
bugs — revisit if thinking is turned on for roxygen), 8 (style ceilings
are house style — no change), 9 (`ALONG.WITH.name` example — revisit after
the stepwise analysis has run in CI).
