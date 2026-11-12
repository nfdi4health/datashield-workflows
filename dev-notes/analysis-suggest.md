# Analysis starter scripts (idea, in design)

Status: **stage 1 built (2026-09-30), tested locally, not yet run in CI**
(design started 2026-09-29). See "Implementation" below.
Name (decided 2026-09-30): **`datashield-analysis-suggest.yml`**.
Lowercase like all workflow files (in prose it stays "DataSHIELD"). It
follows the `<thing>-suggest` family, and branches are
`bot-suggest/analysis/…`. "initiate" was dropped because the workflow
keeps proposing updates after the first run; a "gets you started" message
can go in the docs page title (e.g. "Start a DataSHIELD analysis"). Fix
the name before the first release: it is part of every caller's `uses:`
path and the federation rules' `job_workflow_ref` claim. This note keeps
its file name `analysis-suggest.md`.

## Idea

A reusable workflow for DataSHIELD **analysis projects**, not for packages.
An analyst describes a whole analysis in a config file. A change to that
file starts a Claude session, like the roxygen and test suggestions. It
builds a starting DataSHIELD analysis script with:

- correct calls;
- assignment of aggregate results to R objects;
- data management;
- modelling and checks of model assumptions, where DataSHIELD allows
  them;
- figure and table files.

The config template and the caller workflow come with a new project from
`dsAnalysis::initProject()`.

The aim is to get people started with DataSHIELD, not to do their job.
The analysis stays the researcher's responsibility. This goes into the
README or the script header, not into the code logic.

## Decisions so far

### How changes are proposed

- **Always a suggestion PR** (`bot-suggest/…`), like the other bots. The
  first run matters most.
- **Incremental after the first run.** The config diff decides which
  sections are added or changed. Full regeneration into a separate folder
  was rejected.
  - **Marker comments:** each generated section carries one naming the
    config entries it came from, plus a checksum of the generated code.
  - **Analyst edits are safe:** a section whose code no longer matches its
    checksum was edited by the analyst. It is never changed; the PR only
    notes what the config change would affect.
  - **Removals:** a removed config entry gives a note in the PR, never a
    deletion.
  - **First run:** the same mechanism, starting from an empty script.

### Data and privacy

- **Claude never sees data**, only the plan in the config. This is a
  deliberate strength: analysts define hypotheses and methods up front,
  close to pre-registration, instead of exploring. The variable names and
  the plan themselves do go to the API; that's the obvious data
  protection point.
- **Data protection: a note, no opt-in** (decided 2026-09-30). The config
  content (variable names, levels, studies, tables, the plan) goes to the
  API; data, credentials and `01_DS_Login.R` never do. The note that the
  config content is sent to the Claude API, and must not contain anything
  confidential, belongs in the **config template header and the dsAnalysis
  README**, not in this repo. The docs page here only points to it.
  - **Why no `send-to-api` setting:** users are worldwide with different
    regulations, so it's the project's own decision, like hosting on
    GitHub. Metadata is increasingly meant to be public anyway (in Europe
    the EHDS asks studies to publish dataset metadata; the user thinks by
    2029). And an opt-in would mean analysts editing settings they don't
    understand.
- **Design goal: analysts never touch the workflow file.** Everything
  analysis-related lives in the config; the caller comes from dsAnalysis
  and just works. Most analysts will have no workflow knowledge, and the
  secrets setup (GitHub App / PAT) is already a hurdle — see the auth
  question below.
- **`.Renviron`** is in `.gitignore` when dsAnalysis creates the project.
  If a user undoes that, it's their responsibility. CI never connects to
  real servers and never uses real credentials.

- **`01_DS_Login.R` belongs to the analyst** (confirmed by the user). It is never generated or
  changed, and never sent to Claude, since credentials may be in it. What
  Claude needs (studies, tables, symbol `D`) comes from the config. R
  checks the file mechanically for hard-coded credentials (a literal
  `password = "…"` rather than `Sys.getenv()`). If it finds any, the PR
  comment warns that they are visible to everyone with repo access, and
  suggests moving them to `.Renviron`. The values are never shown.
- **Middleware doesn't matter.** Opal and Armadillo (MOLGENIS) differ only
  in `01_DS_Login.R` (the `DSOpal` vs `DSMolgenisArmadillo` driver).
  DSLite imitates the DataSHIELD server interface, so the workflow is the
  same for both. On Armadillo the installed server packages come from the
  study's *profile*; the config template should say where to look them up.

### Validation

- **CI runs in dsAnalysis's testing mode** (decided; the user left the
  choice to me). Where dsAnalysis comes from is a workflow input with a
  default (e.g. `dsanalysis-ref: FlorianSchw/dsAnalysis@main`), because
  the org/repo of dsAnalysis will likely change. dsAnalysis will be on
  CRAN in the future, which removes the `Remotes` clash below. CI:
  1. writes the mock data generated from the config to
     `utils/mock_data/bot-suggest/`, next to the CNSIM demo, which stays;
  2. updates `utils/setup/01_DSLite_Setup.R` with dsAnalysis's own
     functions (`add_dsPackage()` / `update_MockData()`, which use marker
     comments), so dsAnalysis stays the only owner of that format;
  3. runs `main.R` with `R_CONFIG_ACTIVE=testing`.

  The PR includes script, mock data and the updated DSLite setup. Its
  comment tells the analyst to set `R_CONFIG_ACTIVE = 'testing'`, restart
  R and run `main.R`: the identical setup CI ran. The alternative, an own
  DSLite harness in the workflow, would also work without dsAnalysis, but
  CI and local testing would differ. Consequence: the workflow depends on
  dsAnalysis.
  - **Versions:** what runs is decided by what CI installs. dsAnalysis's
    DSLite setup only loads what's installed (`library(DSLite)`,
    `defaultDSConfiguration(include = …)`), so the testing mode adds no
    version problem of its own.
  - **Install clash:** dsAnalysis's `DESCRIPTION` has
    `Remotes: datashield/dsBaseClient` (and dsSupportClient), i.e. GitHub
    HEAD, which would clash with or overwrite the pinned client versions.
    Fix: install the pinned DataSHIELD packages first, then dsAnalysis
    without dependencies, plus its non-DataSHIELD imports (fs, usethis,
    here, …); only its file functions are needed. Separately, a point for
    dsAnalysis itself: analysts get GitHub HEAD dsBaseClient, possibly
    newer than their servers' dsBase. It may be better to depend on CRAN
    releases.
  - **Staleness:** if the DSLite template lags behind, CI inherits it, and
    so does every analyst locally. CI will notice when the testing mode
    breaks.
  - **Interface:** the marker comments in `01_DSLite_Setup.R` and
    `dependencies.R` become an interface between dsAnalysis and the
    workflow; change them as deliberately as a workflow input.
  - **Wording:** the PR comment promises identical files and procedure,
    and the same versions only if the analyst installs what
    `dependencies.R` lists. The PR states the tested versions.

- **A script is only proposed after it has run.** It runs in CI against
  DSLite, with mock data **generated from the config**. The config's
  variable section is required and carries, per variable:
  - name and table;
  - type (numeric / binary / categorical);
  - levels or value range;
  - role (outcome, exposure, confounder, …).

  R builds a synthetic table with exactly those names, one per study, so
  the script uses the real names and runs unchanged. The CNSIM mock data
  shipped with dsAnalysis stays for learning, but isn't used for this
  check. A script that runs on mock data can still be statistically wrong;
  the run only catches syntax, function and object errors.
- **No invented functions or arguments.** Generated calls are checked
  against the installed client packages' `formals()` and help. The earlier
  `dsAnalysis_functions_metadata.json` / `FlorianSchw/datashield-workflows`
  metadata tryout will likely be removed, so it isn't a source.
- **Claude returns sections as fields** (purpose, code, objects created,
  output files); R assembles them into dsAnalysis's script structure
  (`01_DS_Login.R`, `02_QualityCheck.R`, …, `main.R`).

### Script files

- **At most 150 lines per script file** (user's proposal), counting all
  lines including comments and markers. R enforces it while assembling;
  a prompt instruction wouldn't be reliable.
- **Naming:** one topic per number, starting at `02_` (`01_` is the
  login), e.g. `02_DataManagement.R`, `03_Descriptives.R`,
  `04_Models.R`. Names come from the config sections. Overflow gets
  letters: `02a_…`, `02b_…`.
- **Splits happen only between sections.** A single section over 150
  lines gets its own file and a note in the PR.
- **Stable names:** later additions get the next free letter. Existing
  files are never renumbered.
- **`main.R`:** the bot updates a marked block that sources the files in
  order.
- **The template's `02_QualityCheck.R`, `03_DescriptiveStatistics.R`,
  `99_DSLiteLearning.R`** were empty placeholders for good practice
  (numeric order makes debugging help easier). The user is removing them
  from dsAnalysis (2026-09-30), so the bot's numbering starts at `02_`
  without conflicts. If a project still has such a file, the bot never
  overwrites it and continues after the highest number in use.

### Package versions

- **The config lists server-side packages with versions, per study.**
  Usable is what all studies have installed. If one study lacks a package,
  Claude points that out.
- **No client packages in the config**, and `renv.lock` isn't relied on
  either: many R users don't use renv, and right after `initProject()`
  nothing extra is installed.
  - **Pairing:** each server package has a client package, by the
    `…Client` naming convention or an explicit pairing from the catalogue.
  - **Version:** the same version as the server package. Otherwise the
    newest with the same major.minor, otherwise the newest, reported in
    the PR.
  - **In CI:** those client versions and the server packages at their
    config versions are installed.
  - **Sources:** most DataSHIELD packages are on GitHub only, not CRAN.
    The location comes from the catalogue's `github_link`, so the config
    names package and version only. CI checks sources in this order:
    1. CRAN, if the package is there;
    2. a GitHub tag or release matching the version;
    3. the default branch, if its `DESCRIPTION` version matches;
    4. otherwise, the mismatch is reported in the PR.

    An optional git ref (tag / commit SHA) in the config pins exactly,
    for packages that never tag.
  - **For the analyst:** the script states the client versions it assumed,
    and the install lines go into `dependencies.R`.
- **`dependencies.R`** exists so renv also records packages without a
  `library()` call, e.g. `dsBase`, which is only needed for DSLite. The bot
  edits only its own marked blocks, in dsAnalysis's marker-comment
  convention:
  1. client packages for the configured server packages (tested);
  2. server packages for local DSLite testing;
  3. **commented out:** client and server packages the study servers
     don't have yet, with what they would enable. renv ignores
     commented-out lines, so nothing is installed by accident.
     Uncommenting lets an analyst try the functions locally in testing
     mode before the servers have them, which can help when asking data
     owners to install a package.

  The file's path is a config entry, defaulting to where `initProject()`
  puts it (project root); its final location isn't decided.

### Package catalogue and gaps

- **A config entry points to the DataSHIELD package catalogue.** Default:
  `https://packages.datashield.org/packages.json`, built nightly from
  `FederatedMethods/packages` (`package_list.csv` + DESCRIPTION / GitHub /
  CRAN). On 2026-09-29 it had 70 packages with name, description, status,
  links, version and dependencies. Its `functions` field exists but is
  empty everywhere.
- **Function catalogue (added 2026-09-30):** the user extracts every
  function of the known packages into `datashield_functions_metadata.json`
  (per function: package, name, `architecture_type` client/server,
  `function_type` aggregate/assign/hybrid, title, description; `category`
  and `status` still empty). For now it's in `FlorianSchw/packages`; a PR
  into `FederatedMethods/packages` is open. Setting `function_catalogue`
  holds the raw URL; only that line changes when it moves.
  - **Contents on 2026-09-30:** 1110 functions in 66 packages, of which
    340 client functions in 21 client packages.
  - **In the prompt:** `read_function_catalogue()` keeps the exported
    client functions (placeholder "XXXX" texts removed).
    `format_catalogue_for_prompt()` lists each package the studies don't
    have with its client functions (~15,000 characters: 38 packages, 206
    functions).
  - **In notes:** "other_package" notes name a function too; the tool has
    an enum of catalogue function names, and `verify_note_functions()`
    clears a function that doesn't belong to the named package.
- **Package status filter (added 2026-09-30, the user's idea):** which
  catalogue packages may be suggested depends on their status:
  `production`, `development`, `unknown` (no status given), `retired`.
  - **Defaults and overrides:** setting `package_status` (default
    `[production]`), overridden by the plan's optional `package-status`
    list. It is the analyst's choice how much risk to accept, so it sits
    in the plan like `package-catalogue`.
  - **What it filters:** only suggestions (the prompt's package and
    function list, and the enums), never the studies' installed packages.
  - **Checks:** unknown values are a plan problem; `retired` gives a note
    in the report.
  - **Report:** the status stands next to the package, e.g. "Survival
    analysis — `dsSurvival` (production), `ds.coxph.SLMA()`: …".
  - **Sizes on 2026-09-30:** 33 production, 19 development, 10 unknown,
    8 retired packages. `[production]` offers 18 packages / 150
    functions; with development 29 / 163; with unknown 38 / 206.
  - **Side effect:** with `[production]`, more requests become gaps
    (issue links), even when a development package offers them.
    Intended: the gap collection shouldn't count work in progress as
    covered.
- **The output falls into three categories:**
  1. **Possible now** (installed server packages): code, checked and run
     on mock data. Only this category produces code.
  2. **Possible with another package:** only a note in the PR. Claude may
     only name catalogue packages (an enum in the tool schema), and R
     checks that the package exists and isn't `retired`. With the
     function catalogue, notes can name the concrete client function,
     checked against the catalogue. They are still not tested. Possible
     later: install the package in CI and try it in DSLite.
  3. **Not possible with any known package (a gap):** described in the PR
     comment, plus the issue link below.

### Gap reports: an "Open issue" link, no secrets

The workflow runs in the analyst's repo. Its `GITHUB_TOKEN` can't write to
another repo, and creating issues elsewhere automatically would need a
credential in every analyst repo:

- a PAT: anyone with write access to such a repo could use it;
- a GitHub App private key: handed to every analyst, open to spam, and a
  key rotation means every repo updates its secret;
- or a hosted relay service.

**Decision:** the PR comment contains a **prefilled "Open issue" link**
(`https://github.com/<owner>/<repo>/issues/new?template=…&title=…&body=…`).
The analyst clicks it and creates the issue under their own account.

- **No secrets, no permissions:** anyone can open issues in a public repo.
- **Privacy:** a gap description can reveal an unpublished research
  question, and the collection repo is public. The analyst sees and
  confirms what gets published.
- **Structure:** an issue template in the collection repo sets labels and
  layout. Labels in the URL are only applied for users with triage rights,
  so the template is the reliable way.
- **Nothing is lost:** if nobody clicks, the gap is still in the PR comment.
- **No duplicate issues (added 2026-09-30, the user's request):** before
  asking Claude, R reads the collection repo's open issues whose title
  starts like the issue template (`fetch_gap_issues()`, read-only with
  the job's `GITHUB_TOKEN`, at most `gap_issues_max`, 200). Claude sees
  them in the prompt and can point a gap to one (`existing_issue`, an
  enum of those numbers); `verify_note_issues()` checks it. The report
  then links "Already requested in #12: see what has happened so far,
  and add your use case there", and offers "Open issue" only for new gaps.
  - **Matching is semantic (Claude), not by title text:** titles come
    from Claude's wording and vary. The prompt asks for the same method,
    not just a related topic.
  - **Only open issues count:** if a request was closed, e.g. because the
    function now exists, a new gap links to a new issue.
- **Target:** configurable (owner/repo). For now one of the user's repos.
  Proposed long-term home: a **dedicated repo in the FederatedMethods
  organisation**, e.g. `FederatedMethods/function-requests`, next to the
  package catalogue. That needs agreement from the organisation's
  maintainers; technically it needs only the repo and an issue template.

### Configurability

Like the other suggestion workflows, shared defaults can be overridden per
project by a file at the same path (`resolve_shared_path()`). Candidates:

- the prompt and guidance on DataSHIELD analysis conventions;
- mock data settings: rows per study, missing-value share, seed;
- the catalogue URL and the issue target repo;
- file paths: `dependencies.R`, script folder, mock data folder;
- section order and structure.

## Implementation (stage 1, 2026-09-30)

Files:
- **Workflow:** `.github/workflows/datashield-analysis-suggest.yml`, with
  inputs `plan-file` (default `config/analysis-plan.yml`),
  `dsanalysis-repository` and `dsanalysis-ref`, and the same secrets as
  the other bot suggestions. The example caller is
  `examples/datashield-analysis-suggest.yml`: push on the plan file on
  any branch, plus `workflow_dispatch`. The job skips `bot-suggest/*`
  refs.
- **Code:** entry script `R/suggest_datashield_analysis.R`; functions in
  `R/functions/analysis/`, which use only `shared/`.
- **Settings:** `config/analysis-suggest.yml` holds everything
  adjustable without code. Both config files are overridable per
  project, and a copy replaces the file completely. It covers:
  - mock data (rows, missing share, seed, folder);
  - line limit, numbering (first number, reserved numbers), repair
    rounds, test-run timeout;
  - project paths;
  - block markers (an interface with dsAnalysis);
  - variable types with aliases (`numeric`, `binary`, Opal's `decimal`,
    …) mapped to how mock data is generated;
  - catalogue URL, client suffix, excluded functions (login/logout),
    credential pattern, gap issue repo.
- **Texts:** `config/analysis-texts.yml` holds everything the analyst
  reads: script header, `dependencies.R` comments, step statuses, notes,
  PR report and the issue template. Placeholders are `{{KEY}}`, filled
  with the shared `fill_template()`, which stops if a placeholder has no
  value.
- **Claude:** the `datashield-analysis` profile in `config/claude.yml`
  (Opus 5, adaptive thinking); prompt `prompts/analysis-script-prompt.md`.
- **Still in code, on purpose:**
  - the step file marker line (parsed by regex);
  - the check messages meant for Claude's repair round;
  - maintainer errors (setup failures);
  - the install source order.

Flow:
1. `read_analysis_plan()` / `validate_analysis_plan()` fail fast with
   all core problems. Defaults: symbol `D`, step id from the title.
2. Each step is classified by its files' marker line
   (`find_bot_step_files()`):
   - **new** — no files yet;
   - **changed** — untouched files, but the plan hash differs;
   - **unchanged**;
   - **edited** — never overwritten; a note if its plan entry changed.

   A step whose files exist but that is no longer in the plan is
   **removed**: note only.

   If nothing is new or changed, there is no Claude call.
3. Install the usable server packages (`usable_server_packages()`, on
   all studies, lowest version) and their clients
   (`install_ds_package()`, via pak: CRAN → tag `v<ver>` → tag `<ver>` →
   default branch).
4. Mock data: `generate_mock_data()` → `utils/mock_data/bot-suggest/<server>.rda`.
   The DSLite setup is updated via dsAnalysis's `update_MockData()` /
   `add_dsPackage()`, sourced from a checkout (not installed, so its
   `Remotes` can't clash). `add_dsPackage()` is only called for packages
   that are really missing, which works around its bug.
   `check_login_file()`: connections name, credential warning,
   server/symbol mismatch.
5. Claude (`ask_claude_for_scripts()`) gets:
   - the installed client functions with signatures
     (`client_function_reference()`, ~150 functions for dsBaseClient);
   - the catalogue: non-retired, not installed, server packages only;
   - the existing bot scripts;
   - the plan;
   - the requested steps with their file numbers.

   The tool returns sections and notes per step; enums restrict step ids
   and note packages.
6. Checks (`test_step_scripts()`):
   - `check_ds_calls()` flags parse errors, unknown `ds.*` /
     `datashield.*` functions and unknown arguments;
   - `check_column_references()` requires every `"object$column"` string
     to name a plan variable or a `newobj` created by any step. Needed
     because DSLite (permissive privacy level) returns `NA` with "VALID
     ANALYSIS" for an unknown column instead of an error, so the test run
     can't catch invented variables;
   - `run_analysis_scripts()` runs the DSLite setup plus all bot scripts
     in file order via `callr`: `R_CONFIG_ACTIVE=testing`, no project
     `.Rprofile` (renv), no tokens in the environment.

   There is one repair round for failing steps, with their code and
   errors. A still-failing step is not proposed; a changed step keeps its
   old files.
7. Output:
   - **Step files:** `assemble_step_files()` writes `R/NN[a-z]_Title.R`
     files of at most 150 lines, split between sections.
   - **Notes-only files:** a step with no code gets a file with its notes
     as comments, so the gap is visible and the step isn't requested
     again every run.
   - **`R/main.R` block:** source lines for all bot scripts.
   - **`dependencies.R` block** (one block, three parts): packages
     already listed "not yet on servers" stay until the servers have
     them.
   - **Report:** `format_analysis_report()` → `suggestion_report.md`
     (the PR body) and the job summary.
   - **PR:** `commit-updated-files` in `changed` mode opens
     `bot-suggest/analysis/<branch>` → the pushed branch.

Marker formats (an interface; the dsAnalysis template can include the two
blocks empty):
- script, first line: `#### bot-suggest: step=<id> plan=<hash> content=<hash>`.
  `content` covers the rest of the file, so any edit counts. `plan`
  hashes the step entry plus the core (symbol, studies, variables).
- `R/main.R`: `#### bot-suggest: scripts (updated by datashield-analysis-suggest)`
  … `#### bot-suggest: scripts end`.
- `dependencies.R`: `#### bot-suggest: packages (updated by datashield-analysis-suggest)`
  … `#### bot-suggest: packages end`.

If a block is missing, it is appended at the end of the file.

Tested locally (2026-09-30) on a project built from the dsAnalysis
templates, with Claude and the installs replaced by stand-ins and DSLite
with dsBase 6.3.5 real:
- first run: 4 steps, a repair round for an invented argument, a
  notes-only step, and the report with the issue link;
- no change: no Claude call;
- edited script + plan change: left alone, with a note;
- changed step: rewritten under the same number;
- a failed changed step keeps its old script;
- "not yet on servers" packages kept across runs;
- the renv `.Rprofile` is skipped;
- a broken plan lists all problems.

**Refactoring pass (2026-09-30).** The entry script's steps became
functions (`classify_plan_steps()`, `install_study_packages()`,
`assign_step_numbers()`, `test_step_scripts()`,
`format_repair_request()`, `update_dependencies_file()`), and both rounds
now run in one loop instead of closures with `<<-`. Two bugs the stand-in
answers had hidden were fixed:
- **Runtime errors were never detected.** The script list carried step
  ids as names, which `run_analysis_scripts()` kept, so the lookup by path
  found nothing. It now always names results by path.
- **Scripts of requested steps without a new version were left out of
  the test run**, so later steps missed their objects. The run now
  includes every bot script that has no new version.

Re-tested:
- a runtime error, and an unknown column, each leading to repair;
- a step Claude skips: its old script is kept and still runs before the
  next step;
- an edited script with a plan change.

**Configurability pass (2026-09-30).** The settings and texts described
above moved out of R. The two checks share `walk_code()` for walking the
code tree (with the "empty argument" handling in one place), and
`step_code()` for a step's code. `install_ds_package()` keeps a package
that is already installed at the right version, e.g. from a cached or
preinstalled library; dsBase pulls in heavy dependencies.

Re-tested:
- all scenarios, with a plan using the alias `numeric`;
- an unknown type: its message lists the allowed types;
- a project override of `analysis-texts.yml` changes the report.

**Third pass (2026-09-30).**
- **Project config files are merged, not replaced.** Projects' own
  `config/analysis-suggest.yml` / `analysis-texts.yml` are merged over
  the shared defaults key by key (`read_config_yaml()`,
  `utils::modifyList()`). A project writes only what it changes, and a
  new key in the defaults still reaches projects with an older copy.
  Found in testing: a stale full copy without the new `checks:` texts
  crashed the run. This differs from the other workflows, whose
  overrides (`resolve_shared_path()`) replace the whole file; consider
  merging there too.
- **The shared `fill_template()` now stops with a clear message** when a
  template is missing, instead of "index out of bounds".
- **Moved out of R:**
  - the check messages → `texts$checks` (Claude gets them in the repair
    round; the report shows them as the reason);
  - the repair-round wording → `prompts/analysis-repair-prompt.md`;
  - dsAnalysis's profile names (`production` / `testing`) and mock
    decimals → settings.
- **All 141 files in `R/functions/` checked:** one function each, named
  like the file, no other top-level code.
- **Deliberately still in code:**
  - the tool schema descriptions, as in roxygen/tests; the planned policy
    file would move them for all workflows together;
  - the tokens removed from the test run's environment, so no project
    override can give them to generated code.

**Refactoring iterations (2026-09-30, up to 5, each committed):**
1. Plan-check messages moved to `texts$plan`, so everything the analyst
   reads is in `analysis-texts.yml`. `utils/mock_data` became
   `paths$mock_data`, and `update_dslite_setup()` gets the servers
   instead of listing the folder, sorting in `list.files()`'s byte order.
   The entry script is down to wiring (146 lines): the Claude/test loop
   is now `draft_and_test_steps()`, the evaluation
   `settle_step_results()`, and `format_existing_steps()` was extracted.
2. **Bug:** with a marker line doubled (e.g. a copied block),
   `update_marked_block()` appended a new block on every run. It now
   returns "damaged", leaves the file alone and the report says so
   (`texts$notes$block_damaged`). `step_plan_hash()` leaves out the
   derived `kind`, so changing the type aliases in the settings no longer
   rewrites every step. `text_hash()` hashes in memory
   (`tools::md5sum(bytes =)`, R ≥ 4.5), the same on every platform.
3. **Unquoted versions are a plan problem:** YAML reads `dsBase: 6.10`
   as the number 6.1, so the wrong version would have been installed
   silently. Versions that can't be compared (`6.3.2-dev`) no longer stop
   the run; the first study's version is used. The workflow got a
   concurrency group per branch (quick successive pushes no longer
   force-push the same bot branch in parallel) and `timeout-minutes: 60`.
   Checked: mock `.rda` files are byte-identical when nothing changed, so
   there are no churn commits.
4. **The merged settings are checked** before anything runs
   (`check_analysis_settings()`): numbers and ranges, paths, markers,
   variable kinds, a valid credential pattern, `owner/repo`. A typo in a
   project's override stops the run with all problems listed. Checked:
   the example config passes the plan checks and gives sensible mock
   data.
5. **Failures during the run:**
   - A failed Claude call in a repair round no longer aborts the run:
     what passed in round 1 is kept, and the report counts only the
     attempts actually made.
   - A test run over the timeout (e.g. generated code that loops) no
     longer ends as "DSLite setup failed". Every new script counts as
     failing with `texts$checks$timeout` and goes to the repair round;
     the analyst's own scripts aren't blamed.

   Tested with an endless loop (40 s timeout via a project override:
   stopped, repaired, proposed) and a failing repair call.

**Second refactoring cycle (2026-09-30, up to 5 more iterations):**
1. **The example caller follows the repo's conventions:** secret names
   (`ANTHROPIC_ORG_ID`, `ANTHROPIC_SVAC_ID`, `ANTHROPIC_FDRL_ANALYSIS`),
   the optional App secrets, key order.
   - **File names:** the title part is cut to `max_file_title_chars`
     (40).
   - **`assemble_step_files()`** takes `settings` instead of three
     separate values.
   - **CRAN installs are batched:** CRAN packages go in one pak call
     first (`preinstall_from_cran()`, one dependency resolution instead
     of one per package). If that fails, each package is installed on its
     own as before. Locally only the "already installed" path ran; the
     batch call itself is first exercised in CI.
2. **Bug: the symbol wasn't synchronised.** dsAnalysis's DSLite template
   hard-codes `symbol = "D"`, so a plan with another symbol would have
   failed every step in the test run. `update_dslite_setup()` now sets
   the plan's symbol there (tested with `symbol: df`). The prompt
   template now reaches `ask_claude_for_scripts()` through `context` like
   the repair template, instead of as a hidden global.
3. **Bug of the same kind: the connections' name.** Scripts use the real
   login's name for the connections (`check_login_file()`), while the
   DSLite setup creates `conns`. If an analyst renames them (e.g.
   `connections <- DSI::datashield.login(...)`), every step failed in the
   test run. `update_dslite_setup()` now adds a marked alias line
   (`connections <<- conns  # bot-suggest: ...`) when the names differ,
   and removes it when they match again. The login check therefore runs
   before the DSLite update.
4. **Texts no longer hard-code configurable names:** `main.R`,
   `dependencies.R` and the profile names in `try_it`,
   `other_package_intro` and the "removed" status are now `{{MAIN}}`,
   `{{DEPENDENCIES}}`, `{{TESTING}}` and `{{PRODUCTION}}`, filled from
   the settings (`names_in_texts` in the entry script). Tested with a
   project profile `testing: dslite`.
5. **Block updates moved into a function:** `update_project_blocks()`
   now updates `main.R` and `dependencies.R` and reports damaged blocks,
   so the entry script is wiring only (144 lines). The dsAnalysis
   checklist in this note now says the bot also sets the DSLite setup's
   `symbol` and may append the connections alias line. Left for later:
   - the tool schema descriptions (policy file, together with the other
     workflows);
   - each test round reruns all bot scripts: correct, but it grows with
     the project.

**Done 2026-11-12 (branch `agent-suggest/test/analysis-self-test`):**
confirmed a DSLite limitation — with dsBase 6.3.6 `ds.glmSLMA()` fails on
DSLite's own CNSIM data ("'data' must be a data.frame…"; with `D$` in the
formula "object 'new.glm.obj' not found"). New setting
`dslite_untestable` (ds.glmSLMA, ds.forestplot, moved from
`excluded_functions`): Claude may use them where the plan asks; in the test
run (`run_analysis_scripts()`, statement by statement) a failing statement
calling one, and every later statement using a name it assigned, is skipped
and listed; the report notes them per step as "not tested, check on the
real servers" (`notes.dslite_untested`). Other failures still fail the step.
The script header still says "tested … in DSLite" (changing the file after
the test would break the content hash); the report carries the caveat.

**Self-test (2026-11-12):** `self-test.yml` runs
`datashield-analysis-suggest.yml` itself (input `self-test-fixture:
analysis-project`): `tests/self-test/make-analysis-project.sh` builds a
project from the dsAnalysis checkout's templates (so template changes are
tested) plus `tests/fixtures/analysis-project/` (plan with three
DEMO_OBIBA studies on dsBase 6.3.5, `engine: calls`, no catalogues);
Claude's three answers are recorded
(`tests/fixtures/claude-answers/analysis-project.json`, one per step, the
main model with ds.glmSLMA); installs from CRAN, mock data, the DSLite
setup update, the real test runs and the report run as in a caller;
nothing is pushed or counted. `check-results.sh` checks the scripts, the
main.R and dependencies.R blocks, the setup, the untested note and the
provenance. Ran locally end to end (with the installed dsBase version);
not yet in CI. Not covered: the agent engine, repair rounds, the PR.

Earlier: **Open (stage 2): `ds.glmSLMA()` fails in the DSLite test run**, locally
with dsBase 6.3.5, even on the original data (`D`), while `ds.glm()`
works. Study-level meta-analysis code that works on real servers would
be rejected. Check in CI whether this is a DSLite limitation and, if so,
how to handle it (e.g. a list of functions whose test failures only
become notes). Random mock data also makes `glm.fit` warn about
convergence; harmless, warnings aren't treated as failures.

**Not yet tested:** a real Claude answer, the pak installs (CRAN/GitHub
tags), and the PR in CI. That needs the user's test repo created with
dsAnalysis, with the three Anthropic secrets.

### Step by step, with `depends_on` (2026-10-14)

User's idea: a later step fails anyway when an earlier one (data
management) didn't work, so write and test one step at a time.
`draft_steps_in_order()` replaces the single call for all steps:

- **Order:** plan order. Each step goes through `draft_and_test_steps()`
  on its own (Claude, call and column checks, test run of all scripts so
  far, repair rounds).
- **Dependencies** (`step_dependencies()`): a step's optional
  `depends_on:` (ids of steps above it; checked in
  `validate_analysis_plan()`), else all steps above it. `depends_on: []`
  makes a step independent. A step whose dependency failed in this run is
  not attempted: status `blocked`, report text `step.blocked`; it is
  requested again on the next run. A notes-only ("not possible") step
  blocks nothing.
- **A failed step leaves at once:** its new scripts are removed and its
  previous version restored before the next step runs (the scripts are
  printed to the job log first, the former debug block of the entry
  script).
- **Context per step:** the scripts that run before it (kept ones and
  those written in this run; not its own old version, not pending steps)
  and what the last passing test run left on the servers
  (`run_analysis_scripts(connections = …)`: symbols, and with
  dsBaseClient classes, dimensions and columns) — "Objects on the servers
  after those scripts" in the prompt.
- **Cost:** a call per step instead of one, but smaller, and no repair
  rounds spent on consequential errors. The prompt is split at
  `<!-- per request -->`: instructions, function reference, catalogue,
  open issues and plan are cached for the run's later calls (minutes
  apart); the tool schema lists all of the run's step ids so it stays the
  same.
- A failed Claude call for one step is that step's "no answer"; the run
  goes on (before, a failed first call stopped the run).

Tested with stubs (scratchpad `stepwise_test.R`): order, default and
explicit dependencies, plan check, blocking, restore, statuses. **Not
tested:** the object listing against a real DSLite session (DLLs blocked
locally), real Claude, CI. **Docs pending:** `depends_on` and the
step-by-step order in `datashield-analysis-details.qmd` (plan fields) and
the main page; a commented `depends_on` in `examples/analysis-plan.yml`.

## What dsAnalysis needs (checklist for the user, 2026-09-30)

Template (`initProject()`):
1. Remove the empty placeholders `02_QualityCheck.R`,
   `03_DescriptiveStatistics.R`, `99_DSLiteLearning.R` (planned by the
   user).
2. Add a config template `config/analysis-plan.yml` (decided: in a
   `config/` folder, the workflow's `plan-file` default), from
   [analysis-suggest-example-config.yml](analysis-suggest-example-config.yml),
   with the header saying the content goes to the Claude API.
3. Add the caller `.github/workflows/datashield-analysis-suggest.yml`, from
   this repo's `examples/` once built.
4. `R/main.R`: optionally an empty marked block for the bot's `source()`
   lines (markers under "Implementation"); without it the bot appends
   one.
5. `dependencies.R`: optionally the bot's empty marked block (one block
   with three parts: tested clients, DSLite server packages, not yet on
   the servers commented out); without it the bot appends one.
   Suggestion: `.gitignore` must not exclude `utils/mock_data/`; the bot
   commits its mock data there.

Interface — keep stable:

6. The step markers in `01_DSLite_Setup.R` (`#### Step 1: …` to
   `#### Step 7: …`), used by `add_dsPackage()` / `update_MockData()`,
   and the markers in `main.R` and `dependencies.R` (all in the
   `markers:` settings). The bot also edits the DSLite setup itself:
   - it sets `symbol = "..."` in its login call to the plan's symbol;
   - it appends a marked alias line
     (`<name> <<- conns  # bot-suggest: ...`) when the real login names
     its connections differently.

   A template change there should keep one `symbol = "..."` and the
   `<name> <<- DSI::datashield.login(` form.

Functions:

7. **Bug in `add_dsPackage()`:** when every given package is already
   present, `new_dsPackage_length` is 0, and the `1:0` loops write
   `library(Client)` and break block 4. It should be a no-op.
8. `update_MockData()` fits CI. Pass `table_names` so it doesn't parse
   `01_DS_Login.R`. Each `.rda` must hold an object named after its server
   (`study1.rda` → `study1`).

README:

9. The data protection note.
10. A setup guide: the three secrets, plus "Allow GitHub Actions to create
    and approve pull requests".
11. How to try it: `R_CONFIG_ACTIVE = 'testing'`, restart R, run `main.R`.

Package:

12. `DESCRIPTION`: replace `Remotes: datashield/dsBaseClient` with CRAN
    releases (planned).
13. For its own test suggestions (`datashield-type: utility`): `DSLite`
    and `dsBase` in Suggests.

## Open questions

- ~~**MVP scope**~~ Decided, in stages:
  1. config (studies, server packages, variables), mock data, data
     management and descriptives — the whole pipeline end to end;
  2. models and the assumption checks DataSHIELD allows;
  3. figures and tables as files;
  4. incremental updates. Markers and checksums are built in from stage 1.
- **Example analysis plan:** the user will provide one later; design the
  config fields against it.
- ~~**Scope of client packages**~~ Resolved by the two config fields:
  the installed server packages per study (only these produce code) and
  the catalogue URL (only for notes and package locations). Whatever the
  analyst lists is supported. Stage 1 is developed and tested against
  `dsBase` / `dsBaseClient`; other packages get checked deliberately once
  a real use case comes up.
- ~~**Data protection**~~ Decided: a note in the config template and the
  dsAnalysis README, no opt-in (see above).
- ~~**Auth per analysis repo**~~ Decided (2026-09-30): the same as roxygen
  and tests, to stay flexible while cost models for such services are
  still being discussed. The caller passes the Anthropic organisation,
  service account and federation rule IDs as secrets; the GitHub App
  (`app-client-id` / `app-private-key`) stays optional. So the caller
  decides who pays. Remaining hurdle: analysts set up three secrets per
  repo, so the dsAnalysis README needs a step-by-step guide.
  - **Simplifications for later** (checked against the WIF docs on
    2026-09-30). None needs a workflow change; only the setup
    description would change once the cost model is settled.
    1. **One rule for many repos:** a rule matches a `subject_prefix`
       with a trailing `*` (e.g. `repo:<org>/*`), exact claims (e.g.
       `job_workflow_ref` = this workflow at `main`), and/or a CEL
       `condition` (e.g. `repository_owner` in an allowlist, for personal
       accounts). With the `job_workflow_ref` match only our reusable
       workflow's job gets tokens; callers can't add steps to it.
    2. **The IDs aren't secrets:** org, service account and rule IDs are
       identifiers; the security is the signed GitHub JWT matching the
       rule. They could be plain values in the caller dsAnalysis ships.
    3. **No App needed:** analysis repos normally have no required
       checks, so `GITHUB_TOKEN`-created PRs are fine. They only need
       "Allow GitHub Actions to create and approve pull requests" (believed
       off by default; to verify), which can be set org-wide.

    Always set a workspace spending limit when many repos share one org.
  - **One model for all users** (user's wish: several models for
    different user groups would be complicated). Users always enter
    three secrets. A later central setup (option 1) changes only who
    issues the values — the same shared values for everyone — not the
    procedure or the workflow.
- ~~**Where it lives**~~ Decided for now (2026-09-30): a new docs section
  "Analysis projects" next to "Bot suggestions", and a repo description
  like "Reusable GitHub Actions for R packages and DataSHIELD analysis
  projects". The repo structure may change after feedback, e.g.
  DataSHIELD-only parts split from the rest. So build the workflow to be
  easy to move:
  - entry script `R/suggest_datashield_analysis.R` plus
    `R/functions/analysis/`, using only `shared/`;
  - clearly named `config/analysis-*` and `prompts/analysis-*` files;
  - only generic additions to `shared/`; DataSHIELD-specific helpers stay
    in its own folder.
- **Config shape** — first draft in
  [analysis-suggest-example-config.yml](analysis-suggest-example-config.yml)
  (CNSIM-based, 2026-09-30). It is expected to change a lot: the user
  will get input from field experts, and usability will be tuned. Plans
  differ widely (fields, ids, models, some without tables), so the
  design keeps flexibility:
  - **A small fixed core that R validates:** `symbol`, `studies`
    (server names + server packages), `variables` (shaped like an
    Opal/Armadillo dictionary: name, label, type, categories/range,
    role), `package-catalogue`. It is needed for the mock data and the
    package checks; validated fail-fast before any Claude call.
  - **Free `steps`:** an ordered list; only `title` is required, any other
    fields go to Claude as written. One step is one script number
    (`02_`, `03_`, letters on overflow). Markers use the step's `id`, or
    else its title; a rename counts as removed + added and gives a PR
    note, never a deletion.
  - **No table names:** the login assigns tables to the symbol, and
    scripts only use the symbol and server names. Those two must match
    `01_DS_Login.R`; R checks that mechanically
    (`builder$append(server = …)`, `symbol = …`) without sending the
    file to Claude.

## For the agent version: the user's observations (2026-11-12)

From the user's trial runs on `FlorianSchw/DataSHIELD_CONF_DEMO` (private;
not readable from the Claude sessions so far — the App would have to be
installed there to look at the generated scripts).

1. **Unnecessary code.** Repeated `ds.class()` calls that add nothing, and
   many single vectors assigned out of the data frame instead of using
   its columns (`"D$bmi"`). Not yet checked whether those vectors differed
   from the columns. Wanted: a reviewer whose job includes removing
   "garbage" (calls whose result is never used, duplicates, needless
   copies), plus guidance in the config ("use the data frame's columns;
   no exploratory calls unless a step asks for them"). Partly checkable by
   code: a DataSHIELD call whose result is neither assigned nor used, the
   same call twice. Possible causes to look at: the repair round adding
   checks, the prompt's examples, caution about types.
2. **Split the plan into (at least) two files:** the variables (a long
   list, generated by a planned dsAnalysis function, e.g. from the
   servers' metadata) and the analysis plan (core and steps, written by
   people). The user's idea: build it as the first **cross-repository
   implementer test** — dsAnalysis (the function that writes the variables
   file) and datashield-workflows (the bot reads two files). Not a
   client/server pair, but the same mechanism (two checkouts, two linked
   PRs; inputs from item M, which would then need a neutral name rather
   than `server`). Order: agree the file format first (it is the
   interface); the producer (dsAnalysis) and the consumer (the bot) follow
   it. Needs: item M built, a label check caller in datashield-workflows
   (open point 5 in implementer-plan.md). The plan reader stays in R when
   the bot becomes an agent (item O), so the split carries over.
3. **Studies per step:** not every study has the data for every step.
   Options: an explicit `studies:` list per step, or availability per
   study in the variables file (which the dsAnalysis function can record
   when it reads the servers), from which a step's studies follow. Effects:
   the mock data leaves a variable out where a study lacks it; scripts use
   `datasources = conns[c(...)]`; derived variables exist only on those
   servers. A gate checks that a step's calls use the right connections.

   **User (2026-11-12): the analyst decides.** A study can be included
   even if one variable is missing there, so: an explicit `studies:` per
   step, set by the analyst. Availability in the variables file only
   informs (a warning in the report when a step's variable is missing for
   an included study), it never excludes on its own.
4. **Mock data: the analyst's or the plan's** (question 2026-11-12).
   dsAnalysis already builds mock data from modified aggregate
   information of the real servers (`initMockData()` /
   `update_MockData()`). Proposal: use it when the project has it (closer
   to reality: distributions, missingness, which study has what), else
   generate it from the plan as today (CI has no server access). **Claude
   doesn't create the mock data itself:** it's deterministic R work, and a
   writer that makes its own test data can fit the data to its code (the
   independence point of the roles proposal). The agent sees it the way
   an analyst would — through DataSHIELD calls in DSLite, i.e. aggregates —
   not the `.rda` files (deny rule). Open: mock data derived from real
   aggregates sits in the repository and is close to "data"; whether the
   agent may use it is the analyst's call, and the README's data
   protection note has to say what happens with it.

   **How it is chosen (proposal, user prefers a config file over a
   workflow input — workflow files are more sensitive):** one field in
   the plan's core, where the analyst already reads what is sent.
   `utils/mock_data/` can hold several folders (checked in dsAnalysis
   `dev`, 2026-11-12): `demo_obiba/` shipped by `initProject()` (CNSIM1–3,
   objects `study1`–`study3`), one per `initMockData(folder_name =)`
   (default `MockData_New`), and the bot's own `bot-suggest/`. Each holds
   one `<server>.rda` with an object named after its server.
   `update_MockData(folder_name)` writes the chosen folder into step 2 of
   the DSLite setup. So the analyst names the folder:

   ```yaml
   mock-data: plan            # default: generated from this file
   # mock-data: MockData_New  # a folder under utils/mock_data
   ```

   - `plan` stays the default: nothing derived from real data is used
     unless the analyst names a folder.
   - A folder name: checked before anything runs — the folder exists, has
     one `.rda` per study of the plan, each holding an object named after
     that server; otherwise the run stops with a clear message (no silent
     fallback). `bot-suggest` is refused (the bot's own output), and
     `demo_obiba` only fits the demo plan.
   - Not read from step 2 of the DSLite setup: that file changes with
     every `update_MockData()` call and the bot edits it too, so the plan's
     explicit name is the steadier source.
   - The report states which mock data the scripts were tested on.

### What the generated scripts show (DataSHIELD_CONF_DEMO, bot branch, read 2026-11-12)

Branch `bot-suggest/analysis/master`, plan with CNSIM-like variables, steps
data management → descriptives → main model → sensitivity → figures.

- **Calls whose output nobody uses:** `02_DataManagement.R` checks the
  classes twice (5× `ds.class` on `D`, 4× on `D_analysis`), plus
  `ds.colnames` three times, `ds.levels`, `ds.dim` — all only printed.
- **Server-side objects never used:** `DIS_DIAB_F`, `GENDER_F`,
  `MEDI_LPD_F` ("factor versions, kept as separate server-side vectors")
  are created and never referenced in any later script; the models use
  `D_analysis`'s columns. This is the "single vectors" the user saw.
  Also `bmi_quant` / `tsc_quant` (computed, printed, not in Table 1),
  `dim_all` / `dim_cc` (printed, not saved).
- **Leftovers of debugging:** `03a` has a section "Inspect the shape of the
  ds.mean/ds.var output before building the table" that prints column
  names "so the column indices used below are easy to check".
- **Defensive code:** `04` wraps every fit element in a `get1()` fallback
  ("may be absent depending on the server version") — the version is
  known and tested.
- **Redundant work:** `04` recomputes ORs and CIs by hand although
  `ds.glm(CI = 0.95)` returns them (its own comment says so); `05`
  repeats the same block (copy, not a shared helper).
- **Beyond the plan:** `06` adds a pooled histogram and writes per-study
  bin counts to a CSV (not asked; counts are a disclosure-relevant
  output, even if the smallCellsRule applied). The plan's study-level
  meta-analysis and forest plot are missing (`ds.glmSLMA` / forest plots
  are excluded in the test environment); check the report said so.
- One step became two scripts (`03a`, `03b`): `max_script_lines` (150)
  splits longer steps; the garbage above is part of why it was long.

**Likely cause — and why an agent helps:** the one-shot bot can't look at
anything, so it writes the looking into the script (print the classes,
print the shape) and hedges (fallbacks); the repair round adds more. An
agent can inspect objects in its own session and keep only the final code
in the script.

**Gates to add (code, no Claude):** server-side objects (`newobj`) never
referenced later in any script; client objects assigned and never used
(lintr's `object_usage_linter`); top-level calls whose result is only
printed (allowed only where a step asks to show something); outputs not
asked for by the step's `outputs`. **Guidance:** use the data frame's
columns; no inspection calls; take what DataSHIELD functions return
instead of recomputing; one helper for repeated table code; don't add
outputs the plan doesn't ask for; say explicitly when a requested part
(e.g. meta-analysis) is left out. **Reviewer:** a "clean code" pass that
removes such things and cites the gate findings.

### Built (2026-11-12, branch `agent-suggest/feat/analysis-plan-fields`)

- `mock-data` in the plan's core (`plan` default, or a folder name):
  `validate_analysis_plan()` checks the form, `check_project_mock_data()`
  the folder (exists, not the bot's own, one `<server>.rda` per study with
  an object named after its server), stopping with a clear message; the
  analyst's files are never rewritten or committed by the bot. The report
  says which mock data was used.
- `studies` per step (analyst's choice, servers of the plan, each once):
  the prompt asks for `datasources = conns[c(...)]` and a note where a
  variable may be missing; `check_step_datasources()` flags calls in such a
  step that pass no `datasources` or the whole connections object.
- `examples/analysis-plan.yml` shows both. dsAnalysis's own copy of the
  template (`initProject()`) needs the same two comments.
- Tests: `tests/testthat/test-analysis-plan-fields.R`. Not yet run with
  real DSLite or in CI.

### Built (2026-11-12, branch `agent-suggest/feat/analysis-clean-code`)

- `code_style` in `config/analysis-suggest.yml`: the clean-code rules,
  written into the prompt (`{{CODE_STYLE}}`); a project's config replaces
  the list. The prompt no longer asks to print `ds.colnames()` after
  `ds.dataFrame()` (one cause of the inspection calls).
- `inspection_functions` (settings) + `check_inspection_calls()`: an
  unassigned top-level call of one of them is a problem for the repair
  round.
- `find_unused_objects()`: after the run, over all bot scripts — server
  objects (`newobj` / `newobj.name`) no other string names, R objects no
  other expression uses (print-only lines and inspection calls don't
  count); listed in the report as notes. Run against the demo scripts it
  finds exactly the ones listed above (`DIS_DIAB_F`, `GENDER_F`,
  `MEDI_LPD_F`, `dim_all`, `dim_cc`, `bmi_quant`, `tsc_quant`, plus the
  unused assignment `bmi_hist_pooled`).
- Not yet: removing them automatically (a cleanup round, or the agent's
  reviewer in item O).

### Built (2026-11-12, branch `agent-suggest/feat/analysis-agent`): the agent (item O)

- Settings `engine: agent` (default) or `calls`; with the secret
  `claude-code-oauth-token` (the analyst's subscription) always `agent`.
  The three WIF secrets are optional now; the agent then runs on the WIF
  access token (`ANTHROPIC_AUTH_TOKEN`, Bearer, as our own calls send it —
  not yet tried with Claude Code).
- `ask_claude_for_scripts()` builds the prompt (`analysis_prompt()`) and
  either calls the API or `ask_agent_for_scripts()`: `claude -p --bare`
  (Claude Code 2.1.312, pinned in the workflow) with the same prompt plus
  `prompts/analysis-agent.md`, the same tool schema via `--json-schema`,
  `--permission-mode dontAsk`, tools Read/Glob/Grep, Edit only in
  `.agent/`, Bash only `Rscript <shared>/R/try_analysis_code.R`.
  Everything after (assembling files, checks, test run, repair rounds,
  notes) is unchanged.
- `R/try_analysis_code.R`: runs the DSLite setup, the scripts before the
  step and the agent's file with echo, so the agent can look before it
  answers (tried locally on a DSLite project).
- Sandbox (`agent_settings()`): no network; the real login file and
  `.Renviron` denied to tools and commands; commands write only to
  `.agent/` and `results/`. Claude Code gets only its own credential, the
  helper's R session none (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`,
  `credential_variables()` now also blanks the Claude Code variables).
- Settings `agent.max_turns` (40), `agent.timeout_minutes` (20),
  `agent.model` / `agent.effort` (empty: the profile's). Job timeout 180
  minutes.
- Flags checked against the installed CLI (it parses them; with the
  sandbox it refuses to start without bubblewrap, as intended). **Not yet
  run for real:** a real agent answer, the sandbox on a runner,
  `denyWrite` / `allowWrite` together, the WIF token with Claude Code, the
  subscription's model choice (`claude-opus-5` from the profile; set
  `agent.model` if the plan doesn't include it).
- Mock data: as decided, the agent sees it only through R in its try runs
  (no Read of `.rda` is useful; a Read deny would also block the helper,
  because Read denies are merged into the sandbox).
