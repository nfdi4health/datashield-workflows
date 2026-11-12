# Claude Pro/Max subscriptions instead of WIF

Question (2026-10-14, user): can users run the Claude-assisted workflows on
their own Claude Pro/Max subscription instead of setting up Workload
Identity Federation?

**State: nothing built.** Terms checked 2026-10-16 (below): API with WIF for everything others trigger; the user's own subscription, from a central private repo, for the agents only the user triggers.

## Why it doesn't work as built

Every Claude call goes to the Messages API (`call_claude_tool()`, raw HTTP),
which is billed through a Console organization. A Pro/Max subscription
covers the Claude apps and Claude Code. Its CI token (`claude setup-token`,
used by `anthropics/claude-code-action`) is meant for Claude Code, not for
direct API calls, and as far as known Anthropic's terms don't allow using
subscription credentials that way. Check the current terms before building
anything on it.

## Terms check (2026-10-16, Anthropic's own pages)

Sources: [Claude Code legal and compliance](https://code.claude.com/docs/en/legal-and-compliance),
[Claude Code GitHub Actions](https://code.claude.com/docs/en/github-actions),
[pricing](https://claude.com/pricing).

- **Which terms:** Free, Pro and Max run under the Consumer Terms; Team,
  Enterprise and the API under the Commercial Terms.
- **OAuth (subscription) login** is meant for "ordinary use of Claude
  Code and other native Anthropic applications"; Pro/Max limits assume
  "ordinary, individual usage". Developers building products or services
  (incl. the Agent SDK) must use API keys; routing requests through
  Free/Pro/Max credentials on behalf of others is not permitted.
- **claude-code-action** accepts a subscription token
  (`CLAUDE_CODE_OAUTH_TOKEN`, Pro/Max/Team/Enterprise), but for a secret
  shared across repositories the docs recommend an API key, "since an
  OAuth token is tied to the subscription of the person who ran
  `claude setup-token`". It also supports **workload identity federation
  natively** (`anthropic_federation_rule_id`,
  `anthropic_organization_id`, …) — the same setup as our bots.
- **Prices (2026-10-16):** Pro $17–20/month; Max from $100; Team standard
  seat $20–25, premium seat $100–125 (2–150 seats); Enterprise
  $20/seat plus usage at API rates (20 seats minimum). All plans have
  five-hour and weekly limits; usage beyond them is billed at API rates.

**Conclusion (corrected after the user's context, 2026-10-16):**
- **Triggered by others** (triage, spec review, the existing bots): API
  with WIF; every owner pays through its own Anthropic organization.
- **Triggered only by the user** (implementer, researcher, refactor
  agent): the user's own subscription via claude-code-action is fine.
  The legal page explicitly allows "an end user … signing in to the
  unmodified Claude Code binary with their own Claude subscription";
  non-commercial, no product or service, nobody else's requests on the
  token, the user decides every run — like pasting an issue into Claude
  Code by hand, only on a runner.
- **Model training (consumer terms):** the target repositories are
  public GPL-3 code and public issues, so the "Help improve Claude"
  setting matters little; checked by the user.
- **Where the token lives:** a **central private repository** of the
  user's (not yet created), the only place with the token. A
  `bot-proceed` in a target repo only sends a `repository_dispatch`;
  the central repo verifies through the API that the label was set by
  the user, checks out the target repo, runs the agent, and opens the PR
  there (App or PAT). A changed workflow in a target repo can't reach
  the token, so no environment approval click is needed.
- **One queue across repositories:** GitHub `concurrency` only works
  within one repo; the central repo has one group, so one agent runs at
  a time (shared five-hour/weekly limits). A group keeps only one
  pending run, so each run works through all approved, not yet done
  items (a work list), and a replaced trigger loses nothing.
- **Token upkeep:** one token in one place; renewal comes up when the
  implementer is built (remind the user then).

## Options considered

1. **Plain API key as an alternative to WIF** (optional
   `anthropic-api-key` secret, used when the three WIF IDs are missing).
   Small change, but still Console billing and a long-lived secret.
   **Not wanted (user, 2026-10-14).**
2. **Run the Claude step through Claude Code** (`claude -p` or
   claude-code-action with the user's `CLAUDE_CODE_OAUTH_TOKEN`). The only
   route a subscription could pay for. Not now, because of the loss of
   control below, a second code path in every Claude-assisted workflow, and
   runs counting against the subscription's usage limits (a sweep can stop
   halfway).

## What "less control" means

R would no longer make one exact request per function with a structured
answer. It would hand a task to an agent that decides how to work on it.

- **Guaranteed structure:** today a forced tool call with our schema
  (enums for reasons, categories and confidence, item limits), enforced by
  the API; "Claude returns fields, R assembles the output" rests on that.
  Claude Code can be asked for JSON, newer versions take a schema, but the
  answer is checked after the agent's work. A violation means a retry or a
  lost function, not a guaranteed shape.
- **What Claude sees:** today R assembles the context exactly (function,
  tests, support files, earlier findings; e.g. `01_DS_Login.R` is never
  sent). Claude Code starts with its own system prompt, loads the
  repository's `CLAUDE.md`, can read any file in the checkout and, unless
  locked down, run commands. The checkout holds the caller's code,
  `.Renviron`-style files and token variables. It would need a strict list
  of allowed tools, no Bash and a cleaned environment; even then we only
  restrict what the agent does, we no longer decide it.
- **Per-task settings** (`config/claude.yml`): model per task, adaptive
  thinking with effort, `max_tokens`, server-side fallback, our cache
  breakpoint at `<!-- per function -->`, clean errors on `max_tokens` and
  `refusal`. Model and roughly effort remain settable; cache breakpoints and
  fallback don't. The models available depend on the user's plan.
- **Cost and runtime:** today one call per function (a few with the failure
  classification). An agent takes a varying number of turns (reading files,
  trying things), so tokens and runtime vary unless capped with a maximum
  number of turns; on a subscription that eats into limits the job can't see.
- **Measuring:** `log_claude_usage()` logs input, cache and output tokens
  per call, which the cost pass ([claude-costs.md](claude-costs.md)) and the
  cache check rely on. Claude Code reports per session; on a subscription
  the cost isn't visible at all.
- **Error handling:** our retry rules, token renewal and one warning
  annotation per failed function (job stays green) would become "the CLI
  exited non-zero", with Claude Code's own retries underneath.

**Conclusion:** for roxygen, tests and naming, where R builds the output
from small validated fields, the precision comes from the narrow, fully
controlled call. An agent run would give that up. Open-ended tasks such as
the analysis scripts would suit an agent better, if this is ever revisited.

## Subscription pathway (2026-11-12, user: before v1)

Revisited: the earlier "API for everything others trigger" still holds,
but many callers have one person who triggers everything — an analysis
project, a package without collaborators. For them the WIF setup
(Console organization, service account, federation rules, three secrets)
is out of proportion to a Pro/Max subscription they already have.

**Principle: one definition of the Claude work, two transports.**
A task = prompt template + tool schema + profile (`config/claude.yml`).
Both transports read the same; nothing about the task is duplicated.

- **`api`** (today): `call_claude_tool()` → Messages API, token from WIF.
- **`claude-code`** (new): the same assembled prompt and schema handed to
  the unmodified Claude Code binary in print mode, locked down so it
  behaves like one call: no tools, no settings or `CLAUDE.md` loaded, an
  empty working directory, one turn, the answer as JSON checked against
  the schema. Flags to verify against the current CLI docs before
  building (`--tools`, `--setting-sources`, `--max-turns`, structured
  output / `--json-schema`, `--model`, effort). `call_claude_tool()` gets
  a backend switch; the callers of it don't change.

**What carries over, what doesn't:**
- Exact context: yes — no tools means Claude sees only what R sends, like
  today.
- Structure: checked after the answer, with one retry — the path that
  already exists for models without a forced tool choice
  (`tool_choice_type: auto`).
- Model: yes, within the plan. Effort: probably. Cache breakpoints,
  server-side fallback, our own retry rules: no. Token usage: from the
  CLI's JSON output where present; cost is not visible on a subscription.
- Long runs (sweeps, many functions) hit the five-hour limit; the run
  should stop cleanly and leave a `retry` note, as for a failed call.

**Workflow side:** secrets either the three WIF IDs or
`claude-code-oauth-token`; the auth step picks the transport by which is
set (the WIF secrets become optional — not breaking). Usage counting gets
the transport as a dimension.

**Terms guardrail** (re-check the current pages before building): only the
token owner's own use. On the subscription transport the bot runs only for
events by listed logins (an input, default: the repository owner); others'
PRs get no run. Forks never see secrets anyway.

**Agents and skills (the overlap):** the same rule — prompts, schemas and
guidance live once (here), local Claude Code skills and the workflows read
them. A prerequisite: the tool schemas are built in R today; moving them
into files (e.g. `schemas/*.yml`) lets non-R consumers use them.

### Built (2026-11-12, branch `agent-suggest/feat/subscription-transport`)

- `call_claude_tool()` switches to `call_claude_code_tool()` when
  `CLAUDE_CODE_OAUTH_TOKEN` is set and the run has no API token: Claude
  Code 2.1.312 with `--bare --tools "" --json-schema` (the tool's schema,
  strict as for the API), `--max-turns 3`, the profile's model and effort,
  in an empty temporary folder, with only its own credential. The prompt
  goes as one text (no cache marker). `read_claude_code_result()`,
  `log_claude_code_usage()`.
- `roxygen-suggest.yml`, `test-suggest.yml`: secret
  `claude-code-oauth-token`, the WIF secrets optional (with both, WIF is
  used); input `subscription-logins` (default: the repository owner) — a
  run started by anyone else is skipped with a notice. Claude Code is
  installed only for such runs.
- Item O's analysis agent has its own `read_agent_result()` (PR #58);
  once both are merged it should use the shared
  `read_claude_code_result()` (one function per job).
- Not yet run for real.
