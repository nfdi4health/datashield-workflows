// Shared helpers of the implementer (dev-notes/implementer-plan.md): the
// GitHub API, label names, and what may reach GitHub as text.

import { appendFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";

export class Refusal extends Error {}

export function githubApi(token, fetchFn = fetch) {
  return async (path, { method = "GET", body } = {}) => {
    const response = await fetchFn(path.startsWith("https://") ? path : `https://api.github.com/${path}`, {
      method,
      headers: {
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "datashield-implementer",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`${method} ${path}: HTTP ${response.status}`);
    if (response.status === 204) return {};
    const text = await response.text();
    return text ? JSON.parse(text) : {};
  };
}

// Every page of a list. `path` may carry a query already.
export async function listAll(api, path) {
  const all = [];
  const sep = path.includes("?") ? "&" : "?";
  for (let page = 1; ; page += 1) {
    const rows = await api(`${path}${sep}per_page=100&page=${page}`);
    if (!rows) throw new Error(`${path}: not found`);
    all.push(...rows);
    if (rows.length < 100) return all;
  }
}

// GitHub compares label names ignoring case.
export const sameLabel = (a, b) => String(a).toLowerCase() === String(b).toLowerCase();
export const hasLabel = (issue, name) => (issue.labels ?? []).some((l) => sameLabel(l.name ?? l, name));

export function labelNames(env = process.env) {
  return {
    proceed: env.LABEL_PROCEED || "bot-proceed",
    inProgress: env.LABEL_IN_PROGRESS || "bot-in-progress",
    completed: env.LABEL_COMPLETED || "bot-completed",
    failed: env.LABEL_FAILED || "bot-failed",
    needsInput: env.LABEL_NEEDS_INPUT || "bot-needs-input",
    suspicious: env.LABEL_SUSPICIOUS || "bot-suspicious",
  };
}

export function splitLogins(text) {
  return String(text ?? "").split(/[\s,]+/).filter(Boolean);
}

// Text written by Claude reaches GitHub only through this: no mentions
// (nobody is notified by the agent's words) and no closing keywords (people
// close issues, by merging; dev-notes/implementer-plan.md).
const CLOSING = /\b(close[sd]?|fix(?:e[sd])?|resolve[sd]?)(:?\s+)((?:[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)?#\d+)/gi;
export function stripClosingKeywords(text) {
  return String(text ?? "").replace(CLOSING, (_, _kw, _sep, ref) => `refs ${ref}`);
}
export function safeText(text) {
  return stripClosingKeywords(text).replace(/@(?=[A-Za-z0-9_-])/g, "&#64;");
}

export async function writeOutputs(values) {
  if (!process.env.GITHUB_OUTPUT) return;
  const lines = Object.entries(values).map(([key, value]) => {
    const text = String(value ?? "");
    if (!text.includes("\n")) return `${key}=${text}\n`;
    const delimiter = `out-${randomBytes(12).toString("hex")}`;
    return `${key}<<${delimiter}\n${text}\n${delimiter}\n`;
  });
  await appendFile(process.env.GITHUB_OUTPUT, lines.join(""));
}

// {"owner/name": {"base": "dev", "setup": "r", "server": "owner/server"}}.
export function parseTargets(json) {
  let targets;
  try {
    targets = JSON.parse(json || "{}");
  } catch {
    throw new Error("The targets input is not valid JSON.");
  }
  const names = Object.keys(targets);
  if (names.length === 0) throw new Error("The targets input lists no repository.");
  for (const name of names) {
    if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(name)) throw new Error(`${name} is not owner/name.`);
    const server = targets[name].server;
    if (server && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(server)) throw new Error(`The server of ${name} is not owner/name.`);
  }
  const owners = new Set(names.map((n) => n.split("/")[0].toLowerCase()));
  if (owners.size > 1) throw new Error("All target repositories must have the same owner (one App installation).");
  return targets;
}
