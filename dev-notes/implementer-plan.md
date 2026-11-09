# Implementer: what is agreed, what is open (2026-11-06)

The next step of the issue flow, after the label check and triage. Nothing
here is built yet. The code that exists is in the private
`FlorianSchw/datashield-agent-runner` (two jobs: `implement` runs Claude and
can't write, `publish` is a clean machine that opens a draft PR), not yet run
for real. Background: [issue-agents.md](issue-agents.md).

## Flow

Triage, then the user sets `bot-proceed`, then the implementer on the
subscription. No spec review step and no second approval.

## Decided by the user

- **Disclosure control:** the implementer suggests it, the user decides in PR
  review. The PR description has a disclosure section: what leaves the server,
  recommended options from the known list (`client-server-pair` and
  `design-note` skills of `datashield-skills`), what happens below the
  threshold, rejected alternatives, open doubts. No fitting option means stop
  and ask. A new function still stops at a design note with the same section.
- **Disclosure reviewer:** works out what the server returns from the code
  first, then compares with the suggestion. The PR shows both views.
- **One correction round**, inside the run `bot-proceed` started. The
  implementer does its own cleanup (no refactor stage) and fixes failing
  deterministic checks. Clear problems go back once, the reviewers check only
  those fixes, a second failure stops, and the PR lists what is open. Matters
  of taste become PR comments. Disclosure disagreements never go back: both
  views stay in the PR for the user.
- **Bots never close issues.** People do, by merging.
- **The implementer's only source is the bot's last triage comment**, as a
  spec of the conversation. The user reads the whole conversation and what the
  bot made of it, and approves that with `bot-proceed`. Outsiders' text never
  reaches the agent that runs commands: triage reads it but can only fill in
  fields, and what it writes goes through `plain_comment_text()`, so hidden
  text doesn't survive either. Decided after first choosing the whole
  conversation as the source, the same day: that handed outsiders' text to an
  agent with commands, on a machine holding the subscription token.
  - **Triage writes a spec section** for `bug` and `idea`: goal, what was
    reported, acceptance criteria, open questions. Not `likely files`: triage
    doesn't read the code. Its text limits have to grow for this.
  - **Flow:** after a discussion, `bot-triage` refreshes the spec, the user
    reads it, then sets `bot-proceed`.
  - **The runner** accepts the bot as `spec_authors` and its marker instead of
    `<!-- agent-spec -->`, and keeps checking that the comment is unchanged
    since the label. Later comments and edits of other comments don't matter
    to it.
  - **Limits:** what the bot's spec misses, the implementer doesn't know, so
    the user has to catch it before approving. An issue can still steer what
    the bot writes, but only into plain text the user reads first.

## Agreed, to build in the runner

- ~~**Closing an issue:** `Closes #<issue>` in the commit message and the PR
  description.~~ **Changed (user, 2026-11-09):** the agent only mentions the
  issue: `Refs #<issue>` in its commits and the PR description, with a note
  that a person changes it to `Closes #<issue>` once the work is done.
  Unfinished work (reviewers disagree, follow-ups) then never closes the
  issue. `publish` strips every closing keyword from Claude's text, the
  issue's own too. The closing itself is `release-issues.yml` (built
  2026-11-09): `mark` on a PR merged into `dev` labels the issues its
  description or commits close `next-release` (GitHub ignores the keywords
  outside the default branch; a mere `Refs` doesn't count); `link` writes
  `Closes #n` for those into the `dev` → `main` PR's description before the
  merge, which closes them; `swap` relabels them `released` after it. No
  commit on `dev` is needed. Untested so far: whether GitHub closes issues
  when `merge-pull-request.yml` merges with `GITHUB_TOKEN`.
- **Branch and commit type:** `agent-suggest/fix/issue-<n>` with `fix:` for an
  issue labelled `bug`, `agent-suggest/feat/issue-<n>` with `feat:` for
  `enhancement`. Any other label stops the run. Set by `publish` from the label,
  never by Claude: the type decides the version. The label is the user's way to
  correct triage before approving. Replaces `branch_prefix` `agent/issue-` in
  `config/runner.json`.
- ~~**`cleanup-suggestion-branch.yml`** has to learn `agent-suggest/`.~~
  Done 2026-11-09 (also only branches of the repository itself, not a
  fork's of the same name; this repository calls it too,
  `cleanup-agent-branches.yml`). The
  roxygen, test and authors bots should run on these branches, unlike
  `bot-suggest/`.

## Showing the state on the issue

- **Run started:** one comment with a link to the run.
- **Draft PR open:** GitHub links it through `Closes`. `publish` swaps
  `bot-proceed` for `bot-in-progress`, a new label for `labels/labels.json` in
  repo-governance.
- **Merged into `dev`:** nothing; the issue stays open until it reaches `main`.
- **Run failed or stopped:** one comment with the reason, no branch or PR.
  Includes an edit during the run, which `publish` already refuses.

`implement` holds no token that can write, so the comments need a small
separate job with the App's token, before and after Claude.

## Open

1. **Reviewers:** proposed one writer and two read-only reviewers (disclosure;
   maintainability and remaining norms), most norms by the deterministic checks.
   The user wanted to discuss this further. They have to run inside the
   `bot-proceed` run, or others could start them on the subscription.
2. **Trigger:** dispatch from the target repository or polling from the runner.
3. **Terms and account:** repeat the terms check of 2026-10-16, and check what
   the team organization means for the subscription.
4. **Network:** limit what the `implement` job can reach, since it holds the
   subscription token. Whether claude-code-action and the runners support that
   is unchecked.
5. **Bypass:** if the runner's GitHub App is not App `5023737`, add it to
   `protect-bot-branches` in repo-governance.
6. **`bot-suspicious`:** the implementer refuses to start while the label is
   on, until a person has looked and removed it.
7. **Stale spec:** after a bug or idea, comments don't refresh the spec, and
   nothing warns. When `bot-proceed` is set and people commented after the
   bot's last spec, remove the label with a note to set `bot-triage` first.
8. **Label check elsewhere:** `dsAnalysis` and `datashield-workflows` have
   `bot-proceed` but no label check caller. Each target repository needs it
   before the implementer runs there.

## Triage, follow-ups

Live on `main` and tested for real on dsSupportClient (2026-11-07). None of
these is needed for the above:

- A "Related" line for similar issues (up to three, numbers checked), recently
  closed issues in what Claude reads, and an issue's state, such as "a PR is
  open".
- Whether a smaller model is enough: compare the Cost page of the `issue-triage`
  workspace with the quality of the specs. The defaults still to confirm are
  the seven categories and the model.
- A corrected answer: editing a comment starts no triage, only a new comment
  does. Add `issue_comment: edited` if this comes up on real issues.
- The cache warning in the triage job ("cache write denied"): R packages are
  installed each time, about a minute, because the job has no `actions: write`.
  Left that way on purpose.
- Issue templates, optional: they help the quality of reports, with the function
  as a helpful field, not as a filter. They belong in the governance repository,
  and must never list `bot-proceed`.

## Other open points from this work

- `dev-notes/issue-agents.md` still says nothing is built, and has an uncommitted
  edit in the main checkout.
- `setup-r` stalled several times on 2026-11-06 and 2026-11-07, on Ubuntu 24.04
  and on 26 alike, so the image is not the cause. The slow and fast 24.04 runs
  differed in region, which is only a hunch. If it goes on: skip R setup in the
  three repo-governance jobs, which only need two R packages. `ubuntu-latest`
  stays.
- Usage counts: the counter files were not maintained from 2026-10-16 to
  2026-11-06, so runs without a file went uncounted. Fixed, but they can't be
  recovered, so the KPIs of that time are too low.
- repo-governance: `feat/protect-bot-branches` is unpushed (check App ID
  `5023737` first), `governance-as-code` is obsolete, and `RULESET_ADMIN_PAT` is
  a repository secret although the README asks for a protected environment
  (`anthropic-admin` needs it too, then). Narrow `R/functions/**` in
  `anthropic.yml` to its own files, so label changes stop starting it.
- Rule IDs as secrets could become repository variables, all together, ideally
  with service accounts per owner (open list in `CLAUDE.md`).

## For later: `client-server-pair` skill in `datashield-skills`

A design rule from testing triage on #71, to add when there is time. A server
function fails below a disclosure limit, and that stays. A client wrapper may
catch that and carry on with the other studies: leaving out connections is
normal for sub-analysis, so it adds nothing an analyst couldn't do by hand, and
the failure already showed the study didn't pass. But the output has to say
which studies were used; that is about a correct analysis, not disclosure.
