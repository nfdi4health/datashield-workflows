// The event log on a branch of the runner's repository (dev-notes/
// implementer-plan.md, "Log"): events.json, append-only, and status.csv,
// rebuilt from it. For the record only; the runner works from the labels.

import { listAll, sameLabel } from "./lib.mjs";

const KEY_FIELDS = ["repository", "issue", "event", "time", "actor", "label", "run_id"];
export const eventKey = (e) => KEY_FIELDS.map((f) => e[f] ?? "").join("|");

const order = (a, b) =>
  String(a.repository ?? "").localeCompare(String(b.repository ?? "")) ||
  Number(a.issue ?? 0) - Number(b.issue ?? 0) ||
  String(a.time).localeCompare(String(b.time)) ||
  String(a.event).localeCompare(String(b.event));

// Entries already in the log are kept as they are; only new ones are added.
export function mergeEvents(existing, incoming) {
  const seen = new Set(existing.map(eventKey));
  const added = incoming.filter((e) => {
    const key = eventKey(e);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  return { events: [...existing, ...added].sort(order), added: added.length };
}

// The issue's own history: opened, label changes of the flow's labels with
// who made them, closed and reopened.
export function timelineEvents(repository, issue, events, flowLabels) {
  const out = [{ repository, issue: Number(issue.number), event: "opened", time: issue.created_at, actor: issue.user?.login ?? "", source: "github", title: issue.title }];
  for (const e of events) {
    if ((e.event === "labeled" || e.event === "unlabeled") && flowLabels.some((l) => sameLabel(l, e.label?.name))) {
      out.push({ repository, issue: Number(issue.number), event: e.event, label: e.label.name, time: e.created_at, actor: e.actor?.login ?? "", source: "github" });
    } else if (e.event === "closed" || e.event === "reopened") {
      out.push({ repository, issue: Number(issue.number), event: e.event, time: e.created_at, actor: e.actor?.login ?? "", source: "github" });
    }
  }
  return out;
}

export function pullEvents(repository, issue, pull) {
  const out = [{ repository, issue, event: "pr_opened", time: pull.created_at, pr: pull.number, source: "github" }];
  if (pull.merged_at) out.push({ repository, issue, event: "pr_merged", time: pull.merged_at, pr: pull.number, base: pull.base?.ref ?? "", source: "github" });
  return out;
}

export function runEvents(run, issueOfRun) {
  const issue = issueOfRun.get(String(run.id));
  const start = run.run_started_at ?? run.created_at;
  const minutes = run.updated_at && start ? Math.round((new Date(run.updated_at) - new Date(start)) / 60000) : null;
  return [{
    repository: issue?.repository ?? "", issue: issue?.issue ?? 0, event: "run", time: start, run_id: String(run.id),
    conclusion: run.conclusion ?? run.status, minutes, source: "actions",
  }];
}

const hours = (from, to) => (from && to ? ((new Date(to) - new Date(from)) / 3600000).toFixed(1) : "");
const csvCell = (value) => {
  const text = String(value ?? "");
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

// One row per issue: the latest state and how long each stage took.
export function statusRows(events, { labels, allowedLogins, released = "released", nextRelease = "next-release" }) {
  const byIssue = new Map();
  for (const e of events) {
    if (!e.repository || !e.issue) continue;
    const key = `${e.repository}#${e.issue}`;
    if (!byIssue.has(key)) byIssue.set(key, []);
    byIssue.get(key).push(e);
  }
  const rows = [];
  for (const [, list] of byIssue) {
    const first = (pred) => list.find(pred)?.time ?? "";
    const opened = first((e) => e.event === "opened");
    const approved = first((e) => e.event === "labeled" && sameLabel(e.label, labels.proceed) && allowedLogins.includes(e.actor));
    const prOpened = first((e) => e.event === "pr_opened");
    const merged = first((e) => (e.event === "pr_merged" && e.base !== "main") || (e.event === "labeled" && sameLabel(e.label, nextRelease)));
    const releasedAt = first((e) => e.event === "labeled" && sameLabel(e.label, released));
    const results = list.filter((e) => e.event === "run_end");
    const last = results.at(-1);
    const title = list.find((e) => e.title)?.title ?? "";
    const minutes = list.filter((e) => e.event === "run" && e.minutes != null).reduce((sum, e) => sum + e.minutes, 0);
    const state = releasedAt ? "released" : merged ? "merged" : last?.result ?? (approved ? "waiting" : "");
    rows.push({
      repository: list[0].repository, issue: list[0].issue, title, state, result: last?.result ?? "", reason: last?.reason ?? "",
      pr: last?.pr ?? "", opened, approved, pr_opened: prOpened, merged_dev: merged, released: releasedAt, runs: results.length,
      minutes, hours_to_approval: hours(opened, approved), hours_to_pr: hours(approved, prOpened),
      hours_to_merge: hours(prOpened, merged), hours_to_release: hours(merged, releasedAt),
    });
  }
  return rows;
}

export function toCsv(rows) {
  if (rows.length === 0) return "";
  const header = Object.keys(rows[0]);
  return [header.join(","), ...rows.map((r) => header.map((h) => csvCell(r[h])).join(","))].join("\n") + "\n";
}

// --- the branch -------------------------------------------------------------

async function readFile(api, repo, branch, path) {
  const file = await api(`repos/${repo}/contents/${path}?ref=${encodeURIComponent(branch)}`);
  if (!file) return null;
  return { sha: file.sha, text: Buffer.from(file.content ?? "", "base64").toString("utf8") };
}

export async function readEvents(api, repo, branch) {
  const file = await readFile(api, repo, branch, "events.json");
  return file ? JSON.parse(file.text || "[]") : [];
}

// The log branch has no history in common with the code: created empty.
async function ensureBranch(api, repo, branch) {
  if (await api(`repos/${repo}/git/ref/heads/${encodeURIComponent(branch)}`)) return;
  const tree = await api(`repos/${repo}/git/trees`, {
    method: "POST",
    body: { tree: [{ path: "README.md", mode: "100644", type: "blob", content: "Event log of the implementer: `events.json` (append-only) and `status.csv` (rebuilt from it).\n" }] },
  });
  const commit = await api(`repos/${repo}/git/commits`, { method: "POST", body: { message: "chore: start the event log", tree: tree.sha, parents: [] } });
  await api(`repos/${repo}/git/refs`, { method: "POST", body: { ref: `refs/heads/${branch}`, sha: commit.sha } });
}

async function writeFile(api, repo, branch, path, text, message) {
  const current = await readFile(api, repo, branch, path);
  if (current && current.text === text) return false;
  await api(`repos/${repo}/contents/${path}`, {
    method: "PUT",
    body: { message, branch, content: Buffer.from(text).toString("base64"), ...(current ? { sha: current.sha } : {}) },
  });
  return true;
}

export async function appendToLog(api, repo, branch, incoming, statusOptions) {
  await ensureBranch(api, repo, branch);
  const { events, added } = mergeEvents(await readEvents(api, repo, branch), incoming);
  if (added > 0) await writeFile(api, repo, branch, "events.json", `${JSON.stringify(events, null, 1)}\n`, `chore: log ${added} event(s)`);
  await writeFile(api, repo, branch, "status.csv", toCsv(statusRows(events, statusOptions)), "chore: rebuild status.csv");
  return added;
}

// The daily pass: issues that are or were in the flow, from the log and the
// current labels, and the runner's runs.
export async function collectEvents(api, { targets, labels, flowLabels, existing, typeLabels, branchPrefix = "agent-suggest/" }) {
  const tracked = new Map();
  for (const e of existing) if (e.repository && e.issue) tracked.set(`${e.repository}#${e.issue}`, { repository: e.repository, issue: Number(e.issue) });
  for (const repository of Object.keys(targets)) {
    for (const label of [labels.proceed, labels.inProgress, labels.completed, labels.failed, labels.needsInput]) {
      for (const issue of await listAll(api, `repos/${repository}/issues?state=all&labels=${encodeURIComponent(label)}`)) {
        if (!issue.pull_request) tracked.set(`${repository}#${issue.number}`, { repository, issue: issue.number });
      }
    }
  }
  const incoming = [];
  for (const { repository, issue } of tracked.values()) {
    const found = await api(`repos/${repository}/issues/${issue}`);
    if (!found) continue;
    incoming.push(...timelineEvents(repository, found, await listAll(api, `repos/${repository}/issues/${issue}/events`), flowLabels));
    const [owner] = repository.split("/");
    for (const type of new Set(Object.values(typeLabels))) {
      const head = encodeURIComponent(`${owner}:${branchPrefix}${type}/issue-${issue}`);
      for (const pull of await listAll(api, `repos/${repository}/pulls?state=all&head=${head}`)) incoming.push(...pullEvents(repository, issue, pull));
    }
  }
  return incoming;
}

// The runner's own runs, with their duration (the minutes they cost).
export async function collectRuns(api, { runnerRepo, runnerWorkflow, existing }) {
  const issueOfRun = new Map(existing.filter((e) => e.event === "run_end" && e.run_id).map((e) => [String(e.run_id), e]));
  const runs = await api(`repos/${runnerRepo}/actions/workflows/${encodeURIComponent(runnerWorkflow)}/runs?per_page=100&status=completed`);
  return (runs?.workflow_runs ?? []).flatMap((run) => runEvents(run, issueOfRun));
}
