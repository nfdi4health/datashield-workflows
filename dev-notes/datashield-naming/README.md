# DataSHIELD argument naming — harmonisation workflow

Status: **check and apply workflows built 2026-10-14, tested locally on a
fixture pair (see "Built"), not yet in CI or on a real package**; draft
rules. Goal: a
breaking release of the DataSHIELD packages with one argument name per
object class/role across functions and packages (today e.g. `newobj` vs
`newobj.name`), done by a workflow rather than by hand. To be discussed in
person with the DataSHIELD developers before the rules are final.

## Files in this folder

| File | What |
| --- | --- |
| `../../config/ds-naming-rules.yml` | Draft rules config v0.1 (the single source of truth; moved there from this folder on 2026-10-14, read by the workflows, a repository's own copy merged over it key by key). YAML, not JSON, because every line carries a comment. `name: [a, b]` = still open (front-runner first); entries have `description`, `param_doc` (standard `@param` text), `aliases`, `status`. |
| `example-ds-naming-check.yml`, `example-ds-naming-apply.yml` | Caller files (kept here, not in `examples/`, while the rules are internal). |
| `survey-191723-results.csv` | Earlier nomenclature survey (15 rows, ~8 complete answers). Git-ignored. |
| `datashield_argument_inventory.csv` | Every function argument of 32 packages × prod/dev (20,046 rows; filter `in_scope == TRUE` → 4,868 latest-track user-facing args) with inferred role, object class, confidence, doc text. 3.8 MB — git-ignored (`*.csv` in this folder); move to a release asset if it must be shared. |
| `inventory-summary.json` | Aggregated tables behind the findings below. |
| `extract.py`, `classify.py`, `aggregate.py`, `versions.tsv` | Python prototype of the inventory (see "Re-running"). First version of step 1 of the workflow; to be ported to R. |

Readable write-up (charts, tables): Claude Doc "DataSHIELD argument naming
inventory" — https://claude.ai/code/artifact/0ed4ca7f-5da3-48f8-9f10-a01fc161f9d4

## Survey results (decided / majority / open)

- Unanimous: client `ds.functionName`, server `functionNameDS` (8/8);
  `datasources` last argument, `...` may follow (7/7); one function per
  `.R` file (7/7); internal functions get a common prefix (7/1).
- Majority: data.frame → `df` (5/5); method/algorithm → `method` (5/7);
  `type` reserved for split/combine/both (6/7); vector → `x` (4/5);
  tibble → `tbl` (4/1); model → `model` (4); new object → `newobj`
  (4 vs 2 `newobj.name`); check flag → `checks` (3/5).
- Open: matrix `mat` 3 vs `matrix` 2; internal prefix `.` 4 vs `int.` 3;
  multiple inputs numbered (`x1, x2`) 3 vs distinct (`x, y`) 2;
  `datasources` 2/7 dissent (`conns`; "implies data moves to the client").
- Argument names rated 2/5 for intuitiveness (median) — motivation line.

## Inventory findings (32 packages, 1,077 user-facing functions)

Packages: dsBase/Client, dsDanger/Client, dsGraphics/Client,
dsMTLBase/Client, dsMediation/Client, dsMeta, dsSurvival/Client
(datashield org); dsExposome, dsImaging, dsML, dsOmics, dsVert + clients
(isglobal-brge); dsTidyverse/Client (molgenis); dsHelper
(lifecycle-project); dsSwissKnife/Client, dsResource (sib-swiss);
dsMice/Client (StuartWheater); dsSyntheticClient (neelsoumya).
prod = master/main; dev = newest `*-dev`/`dev` branch with a higher
version (only dsBase/Client v7.0-dev, dsSurvival/Client v2.3.0-dev,
dsMediation/Client v0.0.4-dev). User-facing = NAMESPACE exports (client)
and DESCRIPTION Aggregate/AssignMethods (server). Class inferred from
`@param` text (roxygen, `man/*.Rd` fallback, 94% documented), then name
and default; ~75–80% precise on spot checks; confidence 55% high / 28%
medium / 18% low.

1. Class-name survey rules are almost unused: `df` 12% of data.frame args,
   `x` 21% of vectors, `mat` 2%, `tbl` 0%, `model` 8% (180 of 1,142).
   Role rules mostly hold: `type` 98%, `datasources` 85%, datasources last
   78%, `newobj` 49% (51 names), `checks` 43%, `method` 26%.
2. Same name, many classes — `x`: 221 args across 8 classes (vector 128,
   data.frame 40, omics 25, matrix 16, …); `data`, `formula` similar. So
   transformation entries must be per function × argument, never per name.
3. Data frames have ~60 names (`data` 51, `x` 40, `df` 38, `data_name` 30,
   `df.name` 27, `dataName` 16).
4. Classes the survey missed: formula, list, omics (ExpressionSet, GDS,
   ExposomeSet), resource; and column-name arguments (`idCol`, `time_col`,
   `outcome`: a string naming a column inside a data frame, not an object).
5. Style split by package family: dot.case (dsBase 82%, dsSwissKnife,
   dsMediation), snake_case (dsVert, dsImaging, dsHelper, dsSurvival dev),
   camelCase (dsMice, dsDanger), capitals (dsMTL). 58% of args are single
   words. dsTidyverse mirrors dplyr (exception).
6. Function names: 49% of client exports match `ds.camelCase` exactly
   (`ds.vert.*`, `ds.imaging.*`, `dh.*`, `dss*` differ); 71% of server
   functions match `nameDS`.
7. **dsBase/Client v7.0-dev already renames** (Tim Cadman, Stuart
   Wheater, perf refactor): server `xvect` → `x`; plot functions `x` →
   `x.name`; `table`/`dataset` → `table.name`/`dataset.name`; `objs` →
   `x.names`; new `classConsistencyCheck` on 26 client functions,
   replacing `checks` in 4. dsSurvival dev: `weights` → `weights_obj`.
   Coordinate before finalising the rules; v7.0 is the natural target
   release since it is breaking anyway.

## Decisions so far (user)

- Canonical name = the class name, **no `.name` suffix** (`df`, not
  `df.name`); client args always name a server object, so string-ness is
  implied. v7.0-dev's `.name` arguments become renames too (2026-10-14).
- Config format: YAML with per-line comments; descriptions and standard
  `@param` text per entry.
- Test files: `test-[<category>[_<category>]-]<target>[-<variant>].R`,
  **category optional**; categories from dsBaseClient (`smk`, `arg`,
  `perf`, `disc`, `discctrl`, `datachk`, `expt`, `math`, `dgr`) plus a
  `bug` qualifier. Two-stage check: regex (605/608 existing files pass),
  then `<target>` must be an existing function, a test dataset (datachk)
  or a listed topic — so a function rename also flags its test files.
- The workflow must cover everything (R code, server side, tests, docs,
  vignettes); manual work is too much.

## Workflow design (agreed shape, not built)

1. **Rules config** (`ds-naming-rules.yaml`) — names, aliases, style,
   order, function/test file patterns, exceptions.
2. **Detect — deterministic.** Parse formals/docs/file names, match the
   rules → (a) a report per package and aggregated (dashboard input),
   (b) a **transformation config**: one entry per function × argument
   (`current`, `proposed`, `rule`, `reason`, `class_inferred`,
   `confidence`, `match`, `linked_server`, `status: proposed|approved|skip`;
   template at the end of the rules file).
3. **Classify — Claude.** Only what code can't settle: low-confidence
   args (~1,500), names used for several classes (`x`, `data`), the
   `reason` texts. Claude writes `status: proposed` entries into the
   transformation config, using `description` as reference; never edits
   code (same principle as the other suggestion workflows: Claude returns
   fields, R assembles).
4. **Approve — human** (`approved` / `skip`).
5. **Apply — deterministic, idempotent.** Renames via the parsed R syntax
   tree (`getParseData`), not regex: definitions, call sites, server-call
   strings, `@param`, tests and test file names. Client + server in
   lockstep (`linked_server`). One PR per package onto a shared
   integration branch (e.g. `next`); merge only when all are green;
   semantic-release `BREAKING CHANGE` footer.
6. **Prose — Claude, advisory.** Vignettes / free doc text as suggested
   changes, not commits.

Safety net (design first): throwaway DataSHIELD stack in CI (Opal and/or
Armadillo containers, or DSLite as a first step) with client and server
branches installed, running the integration tests — catches client/server
mismatches unit tests can't. Doubles as a standing client×server
compatibility check.

## Built (2026-10-14)

Two reusable workflows, both run from the **client** repository (user's
choice), which checks out the paired server repository
(`server-repository`, `server-ref`). A server-only repository can run
them alone (`package-side: server`).

**`ds-naming-check.yml`** (entry `R/check_ds_naming.R`, functions in
`R/functions/ds-naming/`, Claude-assisted, counted like the others):

1. `read_ds_package()` — user-facing functions (client: NAMESPACE
   exports; server: DESCRIPTION Aggregate/AssignMethods), formals by R's
   parser (`read_r_definitions()`), `@param` text (roxygen, else Rd).
2. `link_server_calls()` — client formal → server formal, from
   `call("fooDS", x, ...)` and `paste0("fooDS(", x, ...)` (positional or
   named; `as.symbol()` unwrapped). These are the lockstep pairs.
3. `classify_ds_argument()` — role + class + confidence, a port of
   `classify.py`; server args without a clear class take their client
   counterpart's (`classify_naming_rows()`).
4. Claude (`ask_claude_for_naming()`, profile `ds-naming-classification`,
   Sonnet 5) for low confidence, unknown role, object of unknown class or
   a forbidden name — one call per function, at most `max-claude-calls`.
   Claude returns **role and class only** (enums from the rules file);
   names always come from the rules. Answers are kept in the file's
   `classifications:` with a fingerprint of the argument's default and
   doc, and reused until that text changes. The schema is the same for
   the whole run, the rules part of the prompt is cached when the run
   makes more than one call.
5. `propose_ds_name()` — exceptions/R conventions keep; roles and classes
   → canonical name (open rules: front-runner, `rule_open: true`); column
   args → `<stem>.col` / `.cols`; values → style only (`idCol` → `id.col`).
   `resolve_naming_collisions()` — same class twice → numbered (`df1`,
   `df2`) or the listed pairs (`x`, `y`); a name another kept argument has
   → `unresolved` with a conflict note. `propose_naming_rows()` — a
   linked server argument gets the client's new name.
6. `merge_naming_entries()` — people's `approved`/`skip` (and a changed
   `proposed` on an approved entry) survive re-runs; `applied` stays as
   history. Previous decisions come from the open review PR's branch,
   else the base branch.
7. Output: `.github/ds-naming/transformations.yml` (entries only for
   renames, conflicts and unresolved; no dates/commits, so an unchanged
   result makes no commit) + `report.md` (per package; plus report-only
   checks: function name patterns, `datasources` last, test file names
   stage 1+2). Proposed as one PR on `bot-suggest/ds-naming/<base>`
   (force-pushed, `propose-branch` action).

**`ds-naming-apply.yml`** (entry `R/apply_ds_naming.R`, no Claude): on
push of the transformation file (= review PR merged) or by hand.
`approved_renames()` checks each approved entry against the code (already
renamed → marked applied; new name taken → conflict, not renamed;
function gone → reported). `apply_naming_to_package()`:

- R code under `R/`, `tests/`, `vignettes/` by **parse data**
  (`find_r_rename_edits()`): the formal, uses in the body (not `x$old`),
  calls `fn(old = )` / `pkg::fn(old = )` anywhere, and named server calls
  `call("fooDS", old = )`. Every edit is verified against the text before
  it is made (`apply_token_edits()`, tab-aware columns); a file that would
  not parse afterwards is left alone. Strings in the body mentioning the
  old name (error messages) are listed for a person, not changed.
- Roxygen: the function's own `@param` and `\code{old}` / `` `old` ``;
  calls in examples of any block (text fallback
  `rename_call_args_text()`, only `old =` directly inside `fn( )`).
- `man/*.Rd` (item, usage, `\code{}`, examples) so checks pass before
  `devtools::document()`; vignette/README R chunks (calls only, prose not).
- Line endings and final newline kept.

One PR per repository on `bot-suggest/ds-naming-apply/<target>` into
`base-branch` / `server-base-branch` (e.g. `next`), commit
`refactor!:` with a `BREAKING CHANGE` footer. The client PR also sets the
entries to `status: applied`; merging it runs apply again, which then
finds nothing to do. Unapproved counterparts of a renamed linked argument
are flagged ("out of step"). Needs an App token reaching both
repositories (`resolve-push-token` got a `repositories` input; same owner
only).

**First real run (2026-10-14, local, no Claude):** dsBaseClient + dsBase
`v7.0-dev` (52c57bf / 7cfab53). Check: 117 + 140 user-facing functions,
1,082 arguments, 348 client/server pairs; 336 renames proposed (165 under
an open rule), 84 need a decision (66 functions would go to Claude).
Apply with *everything* approved: 338 client + 206 server files changed;
all R files still parse; `codetools::findGlobals()` per function shows no
new free variable (no missed use of an old name in 301 functions); no
call anywhere (R, tests, Rd, vignettes, comments) still passes an old
name. Fixed along the way (all found only on real code): methods declared
in `inst/DATASHIELD` instead of DESCRIPTION; top-level `pkg::fn()` calls;
YAML 1.1 booleans (`y`, `n`) in the rules — **quote such values**;
numbering only generic inputs (`x`/`y`, `V1`/`V2`, `M1.name`), descriptive
ones (`sex`, `keep.cols`) keep their name; roles never numbered (one
keeps the name, others need a decision); lockstep only when all client
callers of a server function agree (else the one named like it);
`.transmit` suffix kept; tighter new-object / value / column detection;
roxygen blocks with blank lines inside; shared templates
(`man-roxygen/`, `@template`: `classConsistencyCheck` is documented there
for ~20 functions); calls in commented-out code and Rd prose. Scripts used
for verifying (scratchpad, not in the repo): free-variable diff, leftover
calls, formals/`@param` per applied entry. **Quality of the proposals:**
mostly sensible; still debatable cases for the meeting, e.g. `ds.table`
`rvar` → `rvar.col` but `cvar` → `x` (doc wording differs),
`classConsistencyCheck` → `checks` (front-runner of an open rule, 23×),
`x.name` with unknown class (left for Claude).

**Tested locally** (fixture client/server pair, scratchpad): check output
and file, approve-all → apply diff (formals, body, nested calls, tests,
Rd usage/items/examples, Rmd chunk; tabs kept), second apply = no change
and only marks applied, re-check keeps applied entries and proposes
nothing; Claude path with a stubbed API (schema, profile, reuse of
classifications). **Not yet:** a real package (dsBase/Client v7.0-dev),
a real Claude answer, the two workflows in CI, `propose-branch` (push and
PR) and the App token for two repositories.

**Not built (later steps of the design):** step 6 (Claude on vignette
prose, advisory), the throwaway DataSHIELD stack in CI, deprecation
shims, function renames (only reported), reordering arguments (only
reported), `@param` text harmonisation from `param_doc`, renaming in
other packages that call the renamed functions.

## Open questions (for the in-person discussion)

- `checks` vs v7.0-dev's `classConsistencyCheck` — same flag or separate?
- Separator for multi-word names: dot.case or snake_case?
- matrix (`mat`/`matrix`), list, omics, resource names; factor separate
  from vector?
- Column-name args: suffix `.col`/`_col`?
- Internal prefix `.` vs `int.`; multiple inputs numbered vs distinct
  (exception list for `x`/`y` pairs drafted).
- Function prefixes `dh.`, `dss`, `ds.vert.`, `ds.imaging.`: exception or
  rename? Keep `.transmit` suffix on server args?
- Deprecation shims (old names accepted with a warning) or hard break?
- Scope of the first round: dsBase/Client only, or all packages.
- Rename `datasources` given the 2/7 objection?

## Second idea (not started)

Functions that only take one input vector should accept a list of vectors
(columns) or a selector argument (e.g. all categorical / all continuous
variables). Needs one consistent contract across functions; saves round
trips, but disclosure checks must still run per variable and output
size/structure changes.

## Re-running the inventory

Python 3 + pandas (no R needed). Clone bare with `--filter=blob:none`,
export `R/` and `man/` per track with `git archive`, extract the
DESCRIPTION methods and NAMESPACE exports (shell loops; see the
conversation of 2026-10-14), then:

```
python3 extract.py <src_root> versions.tsv args.csv
python3 classify.py <scratch_dir>     # reads args.csv, methods.tsv, exports.tsv
python3 aggregate.py <scratch_dir>    # writes summary.json
```

`src_root` layout: `<package>/<prod|dev>/{R,man}`. To port to R for the
workflow: the roxygen/Rd parsing maps onto `R/functions/shared/` (reading
R files) — check what already exists there first.
