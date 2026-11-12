#!/usr/bin/env node
// Entry point of the implementer's steps: node implementer.mjs <command>.
// Settings come from the environment (set by implement-issue.yml), never
// from issue text. See dev-notes/implementer-plan.md.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Refusal, githubApi, labelNames, parseTargets, splitLogins, writeOutputs } from "./lib.mjs";
import { parseRequest, pickNext, verifyIssue } from "./queue.mjs";
import { finalOutcome, nextRound, readExecution, readJson, splitDisclosureReview } from "./outcome.mjs";
import { publish, readResult, prepareBranch, setLabels } from "./publish.mjs";
import { appendToLog, collectEvents, collectRuns, readEvents } from "./log.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const env = process.env;

export function config(e = env) {
  return {
    labels: labelNames(e),
    allowedLogins: splitLogins(e.ALLOWED_LOGINS),
    triageAuthor: e.TRIAGE_AUTHOR || "github-actions[bot]",
    specCategories: splitLogins(e.SPEC_CATEGORIES || "bug idea"),
    typeLabels: JSON.parse(e.TYPE_LABELS || '{"enhancement":"feat","bug":"fix"}'),
    issueTypes: JSON.parse(e.ISSUE_TYPES || '{"Feature":"feat","Bug":"fix"}'),
    openPullRequest: e.OPEN_PULL_REQUEST !== "false",
    branchPrefix: e.BRANCH_PREFIX || "agent-suggest/",
  };
}

// The last run_end of the log decides whether the runner is paused.
export function pausedUntil(events, now = new Date()) {
  const last = events.filter((e) => e.event === "run_end").at(-1);
  if (last?.result !== "limit" || !last.paused_until) return "";
  return new Date(last.paused_until) > now ? last.paused_until : "";
}

// Prompt templates live in this repository's prompts/; {{NAME}} is replaced.
export function fillPrompt(template, values) {
  return template.replace(/\{\{([A-Z_]+)\}\}/g, (match, name) => (name in values ? String(values[name]) : match));
}

export function promptValues(e) {
  const round = Number(e.ROUND || 0);
  const disclosureScope = round === 0
    ? "This is the first review of the change."
    : "This is the re-check after the correction rounds: your earlier review is `.agent/review-disclosure.md`, its deviations `.agent/review-disclosure.json`. Check whether each deviation is fixed (keep it in `deviations` if not), and update the review to the code as it is now.";
  const scope = round === 0
    ? `Review the whole change: \`git diff origin/${e.BASE}...HEAD\`.`
    : `This is the check after correction round ${round}: review only the fixes, \`git diff ${e.SINCE}..HEAD\`, and whether the \`must_fix\` points of the previous review (\`.agent/review-maintainability.json\`) are fixed. Points still open stay in \`must_fix\`.`;
  const server = e.SERVER
    ? `The server package \`${e.SERVER}\` is checked out read-only in \`.agent/server\`. If the change needs a change there too, stop and ask (\`.agent/needs-input.md\`): changes to both packages in one run aren't supported yet.`
    : "";
  return { ROUND: round, BASE: e.BASE ?? "", SINCE: e.SINCE ?? "", SCOPE: scope, DISCLOSURE_SCOPE: disclosureScope, SERVER: server, TYPE_NOTE: e.TYPE_NOTE ?? "", ORACLE: oracleNote(e.oracle) };
}

// The tests a separate agent wrote from the spec before the writer started
// (run-oracle.sh, .agent/oracle.json): the writer makes them pass and never
// changes them.
export function oracleNote(oracle) {
  if (!oracle?.sha || !Array.isArray(oracle.files) || oracle.files.length === 0) return "";
  const files = oracle.files.map((f) => `\`${f}\``).join(", ");
  return [
    `**Tests from the spec.** Before you started, a separate agent wrote tests from the spec alone: ${files} (commit ${oracle.sha.slice(0, 7)}; ${oracle.failing} of ${oracle.tests} failed on the code as it was, see \`.agent/oracle.md\`).`,
    "Make them pass. Don't change, delete or skip them: if you think one is wrong, leave it as it is and explain why under **Tests I disagree with** in your summary; a person decides. Add your own tests as usual.",
  ].join(" ");
}

// The maintainability reviewer answers with JSON, perhaps in a code fence or
// with a sentence around it; anything unreadable becomes a comment, never a
// must-fix point.
export function parseReview(text) {
  const raw = String(text ?? "");
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start >= 0 && end > start) {
    try {
      const review = JSON.parse(raw.slice(start, end + 1));
      return {
        must_fix: Array.isArray(review.must_fix) ? review.must_fix : [],
        comments: Array.isArray(review.comments) ? review.comments : [],
      };
    } catch {
      // fall through
    }
  }
  return { must_fix: [], comments: raw.trim() ? [`The reviewer's answer was not valid JSON: ${raw.trim().slice(0, 500)}`] : [] };
}

export function sandboxSettings(hosts) {
  return {
    sandbox: {
      enabled: true,
      failIfUnavailable: true,
      allowUnsandboxedCommands: false,
      network: { allowedDomains: splitLogins(hosts) },
    },
  };
}

const commands = {
  async pick() {
    const cfg = config();
    const targets = parseTargets(env.TARGETS);
    if (env.LOG_BRANCH && env.LOG_REPOSITORY) {
      const until = pausedUntil(await readEvents(githubApi(env.LOG_TOKEN), env.LOG_REPOSITORY, env.LOG_BRANCH).catch(() => []));
      if (until) {
        console.log(`Paused until ${until} (subscription limit).`);
        return writeOutputs({ found: "false", paused_until: until });
      }
    }
    const api = githubApi(env.GH_TOKEN);
    const requested = env.REQUEST_REPOSITORY ? { repository: env.REQUEST_REPOSITORY, issue: env.REQUEST_ISSUE } : null;
    const next = await pickNext(api, cfg, targets, requested);
    if (!next) {
      console.log("No approved issue is waiting.");
      return writeOutputs({ found: "false" });
    }
    writeFileSync(env.SPEC_FILE, next.spec);
    await setLabels(api, next.repository, next.issue, { remove: [cfg.labels.failed, cfg.labels.needsInput], add: [cfg.labels.inProgress] });
    console.log(`Working on ${next.repository}#${next.issue}.`);
    const { repository, owner, name, issue, base, setup, server, serverBranch, type, typeNote, branch, sha, existingPr } = next;
    return writeOutputs({
      found: "true", repository, owner, name, issue, base, setup, server, server_branch: serverBranch,
      type, type_note: typeNote, branch, spec_sha: sha, existing_pr: existingPr,
    });
  },

  // Again before publishing: a label removed or a spec edited during the run stops here.
  async verify() {
    const cfg = config();
    const request = parseRequest(parseTargets(env.TARGETS), env.REQUEST_REPOSITORY, env.REQUEST_ISSUE);
    const verified = await verifyIssue(githubApi(env.GH_TOKEN), cfg, request);
    if (verified.sha !== env.EXPECTED_SPEC_SHA) throw new Refusal("The spec changed while the agent was working.");
    await writeOutputs({ title: verified.title.replace(/\s+/g, " ") });
  },

  async prompt() {
    const template = readFileSync(join(here, "..", "..", "..", "prompts", `implementer-${env.PROMPT}.md`), "utf8");
    const values = promptValues({ ...env, oracle: readJson(".agent/oracle.json", null) });
    await writeOutputs({ text: fillPrompt(template, values) });
  },

  async settings() {
    writeFileSync(env.SETTINGS_FILE, JSON.stringify(sandboxSettings(env.ALLOWED_HOSTS)));
  },

  // A reviewer only reads; its final answer is the review, saved here.
  async "save-review"() {
    const { text } = readExecution(env.EXECUTION_FILE);
    if (env.ROLE === "disclosure") {
      const { markdown, deviations } = splitDisclosureReview(text);
      writeFileSync(".agent/review-disclosure.md", `${markdown}\n`);
      writeFileSync(".agent/review-disclosure.json", `${JSON.stringify({ deviations })}\n`);
      return;
    }
    writeFileSync(".agent/review-maintainability.json", `${JSON.stringify(parseReview(text))}\n`);
  },

  async round() {
    const again = nextRound({
      checks: readJson(".agent/checks.json", {}),
      review: readJson(".agent/review-maintainability.json", {}),
      disclosure: readJson(".agent/review-disclosure.json", {}),
      round: Number(env.ROUND),
      maxRounds: Number(env.MAX_ROUNDS),
    });
    await writeOutputs({ again: String(again), head: execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim() });
  },

  async outcome() {
    const steps = Object.entries(JSON.parse(env.STEPS || "{}"))
      .filter(([id]) => /^(oracle|writer|maintainability|disclosure|roxygen)(\d+|-recheck)?$/.test(id))
      .map(([id, s]) => ({ role: id.replace(/(\d+|-recheck)$/, ""), ran: s.outcome !== "skipped", conclusion: s.outcome, executionFile: s.outputs?.execution_file }));
    const hasCommits = Number(execFileSync("git", ["rev-list", "--count", `origin/${env.BASE}..HEAD`], { encoding: "utf8" })) > 0;
    const outcome = finalOutcome({
      steps,
      checks: existsSync(".agent/checks.json") ? readJson(".agent/checks.json", {}) : null,
      needsInput: existsSync(".agent/needs-input.md"),
      hasCommits,
    });
    outcome.rounds = Number(env.ROUNDS_USED || 0);
    writeFileSync(join(env.OUT, "outcome.json"), JSON.stringify(outcome));
    console.log(`Outcome: ${outcome.result}. ${outcome.reason}`);
  },

  async publish() {
    const cfg = config();
    const out = env.OUT;
    const outcome = readJson(join(out, "outcome.json"), { result: "failed", reason: "The agent's job ended without a result." });
    const bundle = join(out, "agent.bundle");
    const logged = await publish(githubApi(env.GH_TOKEN), {
      repository: env.REQUEST_REPOSITORY, issue: env.REQUEST_ISSUE, branch: env.BRANCH, base: env.BASE, type: env.TYPE,
      title: env.TITLE, labels: cfg.labels, outcome, result: readResult(out), runUrl: env.RUN_URL, existingPr: env.EXISTING_PR,
      openPullRequest: cfg.openPullRequest,
      now: new Date(), timerEvent: env.TIMER_EVENT, timerMaxMinutes: Number(env.TIMER_MAX_MINUTES || 345),
      bundleExists: existsSync(bundle),
      prepare: () => prepareBranch({ bundle, branch: env.BRANCH, base: env.BASE }),
      // The token goes into the URL of this one push; the checkout keeps none.
      push: () => execFileSync("git", ["push", "--force", `https://x-access-token:${env.GH_TOKEN}@github.com/${env.REQUEST_REPOSITORY}.git`,
        `refs/heads/${env.BRANCH}:refs/heads/${env.BRANCH}`], { stdio: ["ignore", "inherit", "inherit"] }),
    });
    await writeOutputs({ result: logged.result, reason: logged.reason ?? outcome.reason ?? "", pr: logged.pr ?? "", paused_until: logged.paused_until ?? "", rounds: outcome.rounds ?? 0 });
  },

  // A run that ended without publishing must not leave the issue marked as running.
  async cleanup() {
    const cfg = config();
    const api = githubApi(env.GH_TOKEN);
    await setLabels(api, env.REQUEST_REPOSITORY, env.REQUEST_ISSUE, { remove: [cfg.labels.inProgress] });
    await api(`repos/${env.REQUEST_REPOSITORY}/issues/${env.REQUEST_ISSUE}/comments`, {
      method: "POST",
      body: { body: `The agent's run ended without a result. \`${cfg.labels.proceed}\` stays, so the issue is tried again with the next start.${env.RUN_URL ? `\n\nRun (private): ${env.RUN_URL}` : ""}` },
    });
  },

  async "log-run"() {
    const cfg = config();
    const event = {
      repository: env.REQUEST_REPOSITORY, issue: Number(env.REQUEST_ISSUE), event: "run_end", time: new Date().toISOString(),
      run_id: env.GITHUB_RUN_ID, source: "runner", result: env.RESULT || "failed", reason: env.REASON ?? "", pr: env.PR ?? "",
      rounds: Number(env.ROUNDS || 0), paused_until: env.PAUSED_UNTIL ?? "",
    };
    await appendToLog(githubApi(env.LOG_TOKEN), env.LOG_REPOSITORY, env.LOG_BRANCH, [event], { labels: cfg.labels, allowedLogins: cfg.allowedLogins });
  },

  async "log-update"() {
    const cfg = config();
    const targets = parseTargets(env.TARGETS);
    const logApi = githubApi(env.LOG_TOKEN);
    const existing = await readEvents(logApi, env.LOG_REPOSITORY, env.LOG_BRANCH);
    const flowLabels = [...Object.values(cfg.labels), "bot-triaged", ...splitLogins(env.RELEASE_LABELS || "next-release released")];
    const fromTargets = await collectEvents(githubApi(env.GH_TOKEN), { targets, labels: cfg.labels, flowLabels, existing, typeLabels: cfg.typeLabels, branchPrefix: cfg.branchPrefix });
    const fromRuns = env.RUNNER_WORKFLOW ? await collectRuns(logApi, { runnerRepo: env.LOG_REPOSITORY, runnerWorkflow: env.RUNNER_WORKFLOW, existing }) : [];
    const added = await appendToLog(logApi, env.LOG_REPOSITORY, env.LOG_BRANCH, [...fromTargets, ...fromRuns], { labels: cfg.labels, allowedLogins: cfg.allowedLogins });
    console.log(`${added} new event(s) logged.`);
  },
};

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const command = commands[process.argv[2]];
  if (!command) {
    console.error(`Unknown command: ${process.argv[2]}`);
    process.exit(1);
  }
  try {
    await command();
  } catch (error) {
    if (error instanceof Refusal) {
      console.error(`Refused: ${error.message}`);
      await writeOutputs({ refused: error.message });
    }
    throw error;
  }
}
