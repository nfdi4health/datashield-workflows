# test-suggest.yml

Reusable workflow that finds under-tested functions in an R package, asks
Claude to draft real testthat tests for them, **runs every generated test**,
and proposes only the ones that pass. Failing candidates are classified and
surfaced for a human instead of being kept or discarded silently.

Sibling of [roxygen-suggest.yml](roxygen-suggest.md); shares its auth,
config and R conventions (see `CLAUDE.md`).

## How it works

Entry script: `R/suggest_tests.R`. Per function file in `files_to_check.txt`:

1. `parse_r_file()` → function name + source; `find_test_files()` finds
   all test files of the R file — `tests/testthat/test-<R file>.R`, plus
   `test-<category>-<R file>.R` in a categorised repository. Named after
   the R file (`test_file_name()`), not the function, since 2026-10-02 (the
   user's decision; the other workflows pair R files and tests the same
   way): dsAnalysis' `R/initMockData.R` defined `initMockdata()` (since renamed), and the
   bot created `test-initMockdata.R` next to `test-initMockData.R`, which
   case-insensitive file systems can't hold both of. The scheme
   (`detect_test_scheme()`, once per run, see "Test file schemes" below)
   recognises R file names and function names;
   `parse_test_file()` finds their `test_that()` blocks (R's parser; only
   uniquely named blocks on their own lines are editable).
2. Every function is reviewed, tested or not (see
   [suggestion-thresholds.md](suggestion-thresholds.md)); a sweep selects
   which functions (see "Sweep scope" below).
3. The existing tests are run first (`run_test_blocks()`), and
   `build_test_evidence()` collects the history: last change of function
   and test file, which changed later, and in a PR whether the PR changed
   the function without its test, plus the function's diff.
   Once per run, `summarize_test_data()` runs the setup/helper files in a
   separate R process (`collect_test_data()`: package loaded from source,
   files sourced from `tests/testthat/` like testthat does) and describes
   the data tables they create — tables inside any DSLite server (read via
   a temporary DSLite session), else plain data frames: rows, columns,
   types, missing values, factor level counts. No other values. A file
   failing partway still yields the tables created before, with a note.
4. For functions needing DataSHIELD connections,
   `detect_connection_approaches()` looks for any way the tests already
   connect (DSLite, DSOpal, DSMolgenisArmadillo, a DSI login) anywhere
   under `tests/testthat/`, and `decide_dslite_setup()` applies the
   `dslite-setup` input: create a DSLite setup, follow the existing
   approach, or (never + nothing found) leave the function untested and
   list it in the report. The `setup*.R` / `helper*.R` files and the
   files they `source()` (`test_sourced_files()`) go to Claude verbatim
   (objects, symbols, connection helpers), within a total of 60000
   characters; for a function without tests also one or two typical test
   files of other functions (`example_test_files()`).
5. `ask_claude_for_tests()` (profile `test-review`: Opus 5 with adaptive
   thinking; prompt `prompts/test-review-prompt.md`, guidance
   `config/test-role-guidance.json`) returns fields only, never assembled
   `test_that()` code: up to `max_new_tests` new tests (description,
   reason, setup code, assertions) and decisions on existing tests
   (update / delete / report, with reason and explanation).
6. `filter_generated_tests()` applies the threshold to new tests,
   `review_existing_tests()` the safeguards to the decisions (see Design
   decisions). `assemble_test_block()` builds the blocks; if a fresh DSLite
   setup is needed, `ensure_dslite_setup_file()` writes `setup.R` — or
   `setup-dslite.R` if a `setup.R` without DSLite already exists, so that
   file is never touched. *Revisable (2026-09-25):* `setup.R` first to
   avoid cluttering packages with files; revisit after feedback.
7. Per touched test file (`apply_test_file_changes()`):
   `rewrite_test_content()` builds a candidate (updates in place,
   deletions, new tests inserted before a clean-up at the end —
   `test_insert_line()` — else appended; everything else line for line;
   a new file via `new_test_file_content()`, with Claude's top-level
   `file_setup_code` / `file_teardown_code` where the package's files
   connect that way), `write_test_file()` writes it and
   `run_test_blocks()` runs it with the package loaded from source — in a
   separate R process (`callr::r()`) without the Claude and GitHub
   tokens (`credential_variables()`, 2026-10-14); the checkout keeps no
   token in `.git/config` either (`persist-credentials: false`).
8. The file is rewritten from the *original* with only what passed: failed
   new tests are left out, a failed update keeps the original test and is
   reported. A generated DSLite setup is kept only if a new test passed.
9. The failing **new** tests of a function (repeats of earlier failures
   left out, `repeated_failure()`) are classified together
   (`classify_failures()`, since 2026-10-16): R decides where the message
   alone does (`obvious_failure_classification()`: parse error, unknown
   function → `bad_test`; missing package → `env_misconfiguration`), the
   rest in **one** call `ask_claude_to_classify_failures()`
   (profile `test-failure-classification`):
   `real_bug` → GitHub issue; `bad_test` / `env_misconfiguration` → PR
   comment, or in a sweep into the report.
10. If new tests were kept, `ensure_testthat_setup()` makes sure R CMD
    check runs them: creates `tests/testthat.R`, adds testthat to
    `Suggests`, and sets `Config/testthat/edition: 3` (edition only when
    the runner is created fresh — an existing suite's edition stays).
    `declare_test_packages()` adds packages the proposed test files use
    but DESCRIPTION doesn't declare (`withr::`, `library(x)`, …) to
    `Suggests` (finding kind `dependency`; 2026-10-14, after R CMD check
    warned about `withr` in dsAnalysis).
11. Written files are listed in `updated_files.txt`; the
    `commit-updated-files` action proposes them. `format_test_summary()`
    gives a one-line statistic (new / updated / deleted tests, DSLite and
    testthat setup created) for the link comment on the originating PR
    (`suggestion_summary.md`) and the top of the PR description.
    `format_test_report()` lays out changes to existing tests (with
    reasons), reported tests and sweep failures like the roxygen report
    (a section per kind, a collapsible group per test file, style from
    `config/report-style.yml`); `publish_test_report()` puts it into the
    suggestion PR's description — or, without a
    suggestion PR, a PR comment (sweep: one issue).

Trigger modes: `changed` (PR — new/modified functions only; commits go to
`bot-suggest/tests/<PR branch>`, opened as a sub-PR into the PR branch
with a link comment on the originating PR) and `all` (sweep — opens a PR
against `sweep-base`).

**Sweep scope:** a sweep doesn't review every function every month. It
takes functions whose file or test file changed within
`sweep-lookback-days` (default 35), plus a rotating share of the rest —
picked by a stable hash of the file name — so each function comes up at
least once per `sweep-rotation-months` (default 6; `0` = all functions
every sweep). Saves Claude calls without lowering quality per call.

## Design decisions

- **Real tests, not stubs.** Runnable `test_that()` blocks with genuine
  assertions — highest value, accepted risk.
- ~~**Never touch existing tests.** Only append, or create the test file.~~
  Revised 2026-09-25 (PR #21 showed why: an outdated test left R CMD check
  red, with a human needed for every such case): existing tests are
  reviewed — updated, deleted or reported — under the safeguards in
  [suggestion-thresholds.md](suggestion-thresholds.md). Key rule: a
  failing test is never adapted to output that may be wrong.
- ~~**Max 5 tests per function**~~ Now `max_new_tests` (default 10) in
  `config/claude.yml` — 5 was too few to check real behavior. Enforced by
  the tool schema (`maxItems`), not by prompt wording.
- **Every test is run before it's trusted.** Tests can be checked
  mechanically; docs can't — use that.
- **A failure is never silently kept or dropped.** Three causes are kept
  apart: bad test, real bug caught, broken environment. Classification
  happens *after* the run, from the actual failure output. Real bugs get an
  issue because it outlives the PR.
- ~~**Only generated tests are judged.**~~ Pre-existing tests are run
  before any change and their results — with the history evidence — go to
  Claude, which decides on them; failures of new tests are classified as
  before.
- **Passing tests are proposed, not pushed** — via a sub-PR into the PR
  branch, like roxygen suggestions, so the PR author has the final say.

## DataSHIELD client packages: DSLite

Server-side packages are tested like any R package. Client-side functions
need a DataSHIELD server, so tests run against **DSLite** — an in-process
server implementation — with real execution, no mocking.

Verified pattern (what `ensure_dslite_setup_file()` generates):

```r
logindata <- DSLite::setupCNSIMTest(packages = c("<client package>"))
conns <- DSI::datashield.login(logins = logindata, assign = TRUE)
# tests use `conns`; the dataset is assigned on every study as "D"
```

**Dataset selection:** an existing DSLite setup (any `setup*.R` / `helper*.R`) is always reused as-is
(e.g. from `DSFunctionCreator::init.dsTest()`). Otherwise Claude picks one
of DSLite's five bundled datasets, listed with descriptions in
`config/dslite-canned-datasets.json`:

| Name | Rows/study | Fits |
|---|---|---|
| CNSIM | 2163 | default: health-style numeric/binary columns |
| DASIM | 10000 | same shape, larger sample |
| DATASET | 71 | types, NA/NULL, value-range edge cases |
| DISCORDANT | 12 | paired concordance comparisons |
| SURVIVAL | 2060 | time-to-event analysis |

The `dslite_dataset` enum in the tool schema is built from the same file,
so it can't drift from what the prompt offers. `datashield-example-env.json`
is **not** used here — it describes the real Opal demo server for roxygen
usage examples, a different scenario.

**Server methods come from the installed *server* package.** DSLite builds
its method table by scanning installed packages for `inst/DATASHIELD`; only
server packages (e.g. `dsBase`, `dsTidyverse`) ship one. The `packages =`
argument above is only a `requireNamespace()` check. So in CI the client's
`DESCRIPTION` must list its server packages (plus `DSLite`, `testthat`),
e.g. under `Suggests`, for `needs: check` to install them — otherwise every
DSLite test fails with an unregistered-method error.

Pitfalls found while building this:
- `.prepare_dslite()` (seen in `dsTidyverseClient`'s tests) is a private
  helper of that package, not a DSLite API.
- Tests must run with the package loaded (`load_package = "source"`);
  without it every test fails in CI with "could not find function".
  pkgload registers the namespace before `setup.R` runs, so this also works
  for a client package that isn't installed.

## DataSHIELD utility packages

`datashield-type: utility` (2026-09-29) is for analyst-side helper
packages, e.g. `FlorianSchw/dsAnalysis` and `dife-bioinformatics/mepr`.
They are neither client nor server, and they mix two kinds of functions:
- **Functions using DataSHIELD connections** (`uses_ds_connections()`: a
  `datasources` argument, `datashield.*()` or `ds.*()` calls), e.g.
  dsAnalysis' `initMockData()`. They take exactly the client path: an existing DSLite
  setup is reused, otherwise a dataset is offered and a setup file is
  generated. That setup goes into `setup-dslite.R` when a `setup.R`
  without DSLite exists, as in dsAnalysis, whose `setup.R` reads
  `config-testing.yml`. The same `DESCRIPTION` requirement applies: DSLite
  and the server packages must be installed.
- **Local functions**, e.g. `initProject()` and `find_script()`, get
  `utility_local` from `config/test-role-guidance.json`. Real runs happen
  in a temp directory (`withr::local_tempdir()`, or the package's own temp
  paths), with assertions on the return value and on the files created.
  Only calls that install packages, reach the network or open RStudio are
  replaced, with `local_mocked_bindings()`.

The choice is made per function because it's structural (argument names,
calls), so the prompt doesn't have to ask Claude to decide.
`check_datashield_type()` stops the run on an unknown type.

Checked locally against the dsAnalysis clone: detection, role texts, and
the study group found via `dsBaseClient`. All dsSupportClient functions
are detected as using connections. Not yet run in CI or end to end.

## Test file schemes and existing setups (designed and built 2026-10-01)

Looked at dsBaseClient and dsBase (2026-10-01):

| | dsBaseClient | dsBase |
|---|---|---|
| Files | 318 `test-<category>-<function>.R` | 92, same scheme |
| Categories | `arg` 95, `smk` 118, `disc`/`discctrl`, `math`, `expt`, `perf`, `datachk`, `*_bug`/`*_dgr` variants | mainly `smk`, plus `arg`, `disc`, `perf` |
| Per function | several files (`ds.mean`: arg, smk, disc, math, expt, perf) | several (`meanDS`: smk, disc, perf) |
| Setup | `setup.R` loads DSLite, DSOpal and DSMolgenisArmadillo and sources `connection_to_datasets/*.R`; driver switchable via `options(default_driver)` (DSLite by default) | local unit tests; disclosure settings in `setup.R` |
| Connecting | each test file calls `connect.studies.dataset.cnsim(...)` and disconnects | — |

**Problems today:**
- **Only `test-<function>.R` is looked for,** so in these repositories every
  function counts as untested. Existing tests are never reviewed, new ones
  duplicate them in a new `test-ds.mean.R`, and the sweep's "recently
  changed" rule misses test changes.
- **dsBaseClient's setup is recognised only by luck** (`setup.R` mentions
  DSLite). Claude doesn't see the sourced connection files, nor that every
  test connects itself, and the "existing setup" guidance wrongly says the
  setup connects.
- **DSLite is imposed:** a package whose tests connect differently (Opal,
  Armadillo, inside the test files) without DSLite or a login in
  `setup*`/`helper*` gets a `setup-dslite.R`.

**Decisions:**
1. **All of a function's test files:** `test-<function>.R` and
   `test-<anything>-<function>.R`, with the function name escaped and
   matched to the end (`ds.mean` ≠ `ds.meanByClass`). They are run and
   reviewed together, and each change to an existing test stays in its
   own file. The sweep's rotation step uses the same pattern.
2. **Scheme recognised automatically, no input** (user's decision: it's
   a single-ecosystem convention, an input only if it becomes more
   widespread). If most test files follow
   `test-<category>-<function>.R` with a recurring set of categories, the
   repository is "categorised". Otherwise `test-<function>.R` stays as
   today.
3. **New tests in a categorised repository:** Claude names a category
   per test, an enum of the repository's categories; R checks it and
   writes the test into `test-<category>-<function>.R`, creating the file
   if needed (the user agreed to option A, one file per purpose). So an
   untested function in dsBaseClient gets e.g. `test-smk-<function>.R`
   and `test-arg-<function>.R`.
4. **Category meanings:** a config list (`test_categories`, with
   defaults for the DataSHIELD categories `arg`, `smk`, `disc`, …),
   overridable per repository. Categories found but not listed reach
   Claude as their abbreviation plus the existing files as examples.
5. **DSLite only where nothing is recognisable:** new input
   `dslite-setup`:
   - `auto` (default): create a DSLite setup only if the package's tests
     show no approach to connecting: DSLite, DSOpal,
     DSMolgenisArmadillo, a `datashield.login` / `newDSLoginBuilder`,
     anywhere under `tests/testthat/`, not only in `setup*`/`helper*`;
   - `create`: the repository consciously wants DSLite. A setup is
     created if there's no DSLite one, even next to another approach
     (old tests e.g. via Opal, new ones via DSLite during a switch);
   - `never`: never create one. Functions needing connections without
     a recognisable setup are reported, not tested.
6. **Claude sees how the tests connect:**
   - the files that `setup*`/`helper*` `source()`, e.g.
     `connection_to_datasets/*.R`;
   - for a function without tests, one or two existing test files of
     other functions as examples of the house style;
   - the "existing setup" guidance no longer claims the setup connects:
     "follow how the existing tests connect".

**Implementation (built 2026-10-01, not yet in CI):**
- **Scheme:** `detect_test_scheme(package_function_names())`: a file is
  categorised if it is `test-<cat>-<fn>.R` with `cat` of letters, digits
  and `_`, and `fn` a top-level function in `R/`; the repository is
  categorised with ≥ 3 such files and ≥ half of all test files.
  A file whose whole name is a function (`test-read-config.R` with
  `read_config()` or `read.config()`) is not categorised, so it doesn't
  become a "read" test of `config()`. Finding files works the same in
  both kinds of repository (user's request): `test-<fn>.R` is always
  found, also in a categorised one, and a plain repository's occasional
  `test-arg-<fn>.R` is found too. Only the placement of new tests
  differs: by category only in a categorised repository, else
  `test-<fn>.R`. dsBaseClient: categorised, 14 categories, `ds.mean` has
  7 files.
- **Placement:** `category` enum in the tool schema (categorised only); an
  unknown category is dropped. `test_file` names the file of each
  decision on an existing test (enum of the function's files); with a
  single file a missing or unknown name falls back to it, otherwise the
  decision is ignored.
- **Files that set up at their top level** (dsBaseClient: connect at the
  start, `test_that("shutdown")` and a disconnect at the end): new tests
  go after the last non-clean-up block (`test_insert_line()`); a new file
  gets Claude's `file_setup_code` / `file_teardown_code`. Not foreseen in
  the design, found while building.
- **Meanings:** `config/test-categories.json` (`arg`, `smk`, `disc`,
  `discctrl`, `math`, `expt`, `perf`, `datachk`), replaced as a whole by
  a project's own copy like the other JSON configs; the `_bug` / `_dgr`
  variants are not described (unclear meaning) and reach Claude as names
  with a pointer to their files.
- **`dslite-setup: never`** with no way to connect: the function is
  logged and listed in the report ("Functions not tested"), but doesn't
  make a report on its own — the repository chose it, and a comment or
  issue every run would be noise.
- **Prompt size:** support plus sourced files are capped at 60000
  characters in total; dsBaseClient's come to ~59600 (~15k tokens per
  function, Opus). Watch the cost on a first real run.
- **Sweep rotation:** a function counts as recently changed if
  `test-<name>.R` or `test-<cat>-<name>.R` changed (`<name>` from the file
  name, as before).
- **Tested locally** (real entry script, Claude and GitHub mocked): helpers
  against the dsBaseClient clone; a categorised sandbox (insertion before
  shutdown, deletion in the right file, new file with top-level setup,
  unknown file/category dropped, failing test classified, example files
  for an untested function); a plain sandbox (unchanged behaviour); all
  `dslite-setup` values incl. a typo and Opal found in a subfolder.

## One report per bot PR (built 2026-10-02)

Same scheme as the roxygen workflow (dev-notes/roxygen-suggest.md, "One
report per bot PR"), after the duplication seen on dsSurvivalClient
PR #37. PR and push runs that build on an open bot PR
(`open-suggestion-pr: add`, no rebuild):
- **Bot's test files in place first:** `materialize_bot_tests()` copies
  every `tests/` file the bot branch changed (since its merge base with
  the branch) into the working tree, unless the user changed it since
  the last review (`BASE_REV`; their version wins, as in the merge). The
  bot's tests then count as existing — run in the baseline, shown to
  Claude — so they aren't generated again. `restore_unproposed_files()`
  puts back what the run doesn't propose, so `commit-updated-files` can
  switch branches.
- **Earlier findings to Claude** (`format_earlier_test_findings()`): open
  notes (reported tests, failing tests left unchanged) and failed
  generated tests, with ids. Schema: `repeats_earlier` on new tests
  (failed ids) and on decisions (note ids), `earlier_findings`.
- **Failures:** a new test that repeats an earlier failed one (by id or
  same name) is still run — if it passes, the earlier failure is
  resolved; if it fails again it is only counted as a repeat: no
  classification call, no comment, no issue.
- **Merge** (`merge_test_findings()`), never deleting: user-edited test
  file → the bot's earlier entries for it crossed out; Claude's
  judgement; a note whose test passes now (or no longer exists, in a
  file that ran) resolved mechanically; an update/deletion replaces
  earlier entries on that test; repeated notes skipped (by id or same
  file + test); created setup files and untested functions added once.
- **Report** (`format_test_report()`), rebuilt each run, new section "New
  tests" (so far only counted). Failed tests appear in it only where
  they were not commented (sweeps, pushes without a PR), with code and
  output. `pr-body-mode: replace`. Without a bot PR, the comment or sweep
  issue gets the report without the hidden state.

**Possible bugs in the code** (built 2026-10-02, user's decision, like
roxygen): the failure classification asks for the reasoning first, then
the category and a `confidence`; decisions on existing tests carry a
`confidence` too. With the confidence in `code-issue-confidence` (input,
else `code_issue_confidence` in the `default` profile of
`config/claude.yml`; high + medium):
- a `real_bug` failure becomes a "bug" entry (origin "failure"), with an
  issue only at **high** (issues outlive the PR and reach every watcher);
  otherwise — lower confidence, or `none` — it is an ordinary failure
  (PR comment / report);
- a `possible_code_bug` report becomes a "bug" entry (origin
  "existing"), else an ordinary note.
Report section "Possible bugs in the code" (medium labelled, issue
linked), summary "· n possible bugs". `create_bug_issue()` and the sweep
report issue use `post_issue_once()` (shared): an open issue with the
same title gets a comment instead of a second issue — the duplicate the
user had seen.

**Tested locally** (real entry script; Claude and the PR lookup mocked; a
real bot branch in a bare remote), three runs: run 2 saw run 1's new test
as existing, added one test, skipped a repeated failure (one failure
comment in total) and a repeated report; run 3 (the code changed)
resolved the earlier note "the test passes now", noted a newly failing
test, and left the working tree clean. The categorised sandbox gives the
same files as before. With bugs: `bad_test` → comment, `real_bug` high →
issue + bug entry with link, `real_bug` low → comment, a medium report →
bug entry (labelled), repeats skipped, the reported test resolved once it
passes; with `none` no issue and no bug section. `post_issue_once()`
checked with a mocked API (new, identical, different, other function,
closed). **Not yet in CI.**

## Status

Verified locally (real entry script, only the Anthropic/GitHub APIs mocked):
plain package; DataSHIELD client package that is not installed, fresh
DSLite setup, pass + fail; all-fail cleanup; pre-existing failing test left
alone; commit action in both modes. First real CI run on dsSupportClient
PR #18 (`changed` mode): auth and the full job ran, but no tests were
generated. ~~Test execution, failure classification and the sub-PR are
still unconfirmed in CI.~~ Confirmed on PR #21 (with the threshold code):
passing tests for `ds.wrapper` (already tested) and `ds.tableBatch`
proposed in sub-PR #24, a failing one classified `bad_test` and commented
on #21, and a later push updated #24 instead of opening a second PR. Not
yet seen: deletion notes, `real_bug` issues, sweeps.

Caller requirements: `datashield`/`datashield-type` inputs, App secrets
(so the suggestion PR triggers required checks), `issues: write`, and the three
`anthropic-*` secrets, with a federation rule for `test-suggest.yml`. No shared
`concurrency` group with `roxygen-suggest.yml` is needed any more: each
pushes to its own `bot-suggest/<kind>/…` branch, never the PR branch.

## Open questions

- **Real coverage data.** Every function is now reviewed and Claude decides
  whether tests add value (see [suggestion-thresholds.md](suggestion-thresholds.md)).
  Per-function coverage (`covr::function_coverage()`) captured by
  `r-cmd-check.yml` and handed over, instead of a second install + test run,
  would still help: as the coverage gain per generated test, and as a hint
  to Claude about uncovered lines.
  Handoff mechanism not designed yet.
- **Changed-function detection.** `changed` mode reuses roxygen's
  `git diff` of `R/*.R` against the PR base — confirm that's the right
  scope for tests.
- **CRAN compliance** of generated tests: deliberately out of scope for now.
