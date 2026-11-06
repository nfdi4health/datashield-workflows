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

- **Closing an issue:** `Closes #<issue>` in the commit message and the PR
  description. Bot PRs go to `dev`, where only the commit's keyword counts,
  once it reaches `main`; the keyword has to survive a squash merge. Written by
  the `publish` job, which also strips other closing keywords from Claude's
  text: a crafted message could otherwise close an unrelated issue.
- **Branch and commit type:** `agent-suggest/fix/issue-<n>` with `fix:` for an
  issue labelled `bug`, `agent-suggest/feat/issue-<n>` with `feat:` for
  `enhancement`. Any other label stops the run. Set by `publish` from the label,
  never by Claude: the type decides the version. The label is the user's way to
  correct triage before approving. Replaces `branch_prefix` `agent/issue-` in
  `config/runner.json`.
- **`cleanup-suggestion-branch.yml`** has to learn `agent-suggest/`. The
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

## Triage, follow-ups

Noted while testing, none needed for the above: a "Related" line for similar
issues (up to three, numbers checked), the start of each body besides the
title, recently closed issues. The line could show an issue's state, such as
"a PR is open".
