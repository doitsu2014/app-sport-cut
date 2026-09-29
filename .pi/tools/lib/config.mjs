// core/tools/lib/config.mjs — project configuration layering.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import {
  configLocalPath,
  configPath,
  detectHarness,
  HARNESS_DIRS,
} from "./paths.mjs";
import { readVersion } from "./version.mjs";

export function loadConfig(root) {
  const base = readJsonOrNull(configPath(root)) || {};
  const local = readJsonOrNull(configLocalPath(root)) || {};
  return {
    harness: base.harness || null,
    defaultScope: base.defaultScope || "classic",
    version: base.version || readVersion(),
    ...base,
    ...local,
  };
}

export function saveConfig(root, patch, { local = false } = {}) {
  const path = local ? configLocalPath(root) : configPath(root);
  const current = readJsonOrNull(path) || {};
  const next = { ...current, ...patch, version: readVersion() };
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(next, null, 2)}\n`, "utf8");
  return next;
}

export function configExists(root) {
  return existsSync(configPath(root));
}

export function resolvedHarness(root) {
  const config = loadConfig(root);
  if (config.harness && HARNESS_DIRS[config.harness]) return config.harness;
  return detectHarness(root);
}

function readJsonOrNull(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}
