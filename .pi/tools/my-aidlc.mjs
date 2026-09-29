#!/usr/bin/env node
// core/tools/my-aidlc.mjs — the my-aidlc command-line engine.
//
// Commands:
//   version | help | init | doctor | status | config | list | stage | phase
//   orchestrate next|report|park
//
// The engine is deterministic: it never makes a decision a human should make,
// and it owns every state transition.

import { copyFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

import { bold, cyan, dim, green, heading, red, warn, yellow } from "./lib/color.mjs";
import { loadMethodology, compileGraph, workflowForScope, scopeByName, detectScope } from "./lib/graph.mjs";
import { configPath, detectHarness, memoryDir, workspaceRoot } from "./lib/paths.mjs";
import { loadConfig, saveConfig } from "./lib/config.mjs";
import { runDoctor } from "./lib/doctor.mjs";
import {
  parkDirective,
  runNext,
  runReport,
  statusReport,
} from "./lib/orchestrate.mjs";
import { loadState } from "./lib/state.mjs";
import { buildHarness, applyDistribution, listHarnesses } from "./lib/packager.mjs";
import { engineRoot, repoRoot, readVersion } from "./lib/version.mjs";

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const flags = {};
  const positionals = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--") {
      positionals.push(...argv.slice(i + 1));
      break;
    }
    if (arg.startsWith("--")) {
      const eq = arg.indexOf("=");
      if (eq >= 0) {
        flags[arg.slice(2, eq)] = arg.slice(eq + 1);
      } else {
        const key = arg.slice(2);
        const next = argv[i + 1];
        if (next !== undefined && !next.startsWith("--")) {
          flags[key] = next;
          i += 1;
        } else {
          flags[key] = true;
        }
      }
    } else if (arg.startsWith("-") && arg.length > 1) {
      flags[arg.slice(1)] = true;
    } else {
      positionals.push(arg);
    }
  }
  return { flags, positionals };
}

function printJson(value) {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function fail(message, code = 1) {
  process.stderr.write(`${red("ERROR")} ${message}\n`);
  process.exit(code);
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

function methodology() {
  return loadMethodology(engineRoot());
}

function cmdVersion() {
  process.stdout.write(`my-aidlc ${readVersion()}\n`);
}

function cmdHelp() {
  const lines = [
    heading("my-aidlc") + dim(` ${readVersion()}`),
    "",
    "USAGE",
    "  my-aidlc <command> [options]",
    "",
    "COMMANDS",
    `  ${cyan("config")}    Configure the project for a harness (${listHarnesses(repoRoot()).join(", ")})`,
    `  ${cyan("init")}      Create the aidlc/ workspace and memory files`,
    `  ${cyan("doctor")}    Validate the engine, workspace, and configuration`,
    `  ${cyan("status")}    Show the active intent, scope, and stage progress`,
    `  ${cyan("list")}      List phases, stages, scopes, or agents`,
    `  ${cyan("stage")}     Show one stage definition`,
    `  ${cyan("scope")}     Show one workflow profile`,
    `  ${cyan("graph")}     Print the compiled workflow graph (JSON)`,
    `  ${cyan("version")}   Print the framework version`,
    `  ${cyan("help")}      Print this help`,
    "",
    "ORCHESTRATION",
    `  ${cyan("orchestrate next")} [--new-intent] [--scope <name>] [--resume] "<description>"`,
    `  ${cyan("orchestrate report")} --stage <slug> --result <outcome> [--user-input <text>] [--reason <text>]`,
    `  ${cyan("orchestrate park")}`,
    "",
    "ALIASES",
    "  --status  --doctor  --version  --help  --config",
    "",
    "The orchestrate commands are what a harness conductor calls. Humans usually",
    "use config, doctor, status, and list.",
  ];
  process.stdout.write(`${lines.join("\n")}\n`);
}

function cmdConfig(flags) {
  const root = resolve(flags.project || process.cwd());
  const harnessName = flags.harness;
  const config = loadConfig(root);

  if (!harnessName) {
    if (flags.json) {
      printJson({ harness: config.harness, defaultScope: config.defaultScope, available: listHarnesses(repoRoot()) });
      return;
    }
    process.stdout.write(`${heading("my-aidlc config")}\n\n`);
    process.stdout.write(`  Harness:       ${config.harness || dim("(not set)")}\n`);
    process.stdout.write(`  Default scope: ${config.defaultScope}\n`);
    process.stdout.write(`  Available:     ${listHarnesses(repoRoot()).join(", ")}\n\n`);
    process.stdout.write(`Run: my-aidlc config --harness <name>\n`);
    return;
  }

  if (!listHarnesses(repoRoot()).includes(harnessName)) {
    fail(`Unknown harness "${harnessName}". Available: ${listHarnesses(repoRoot()).join(", ")}`);
  }

  const outDir = join(tmpdir(), `my-aidlc-dist-${harnessName}-${process.pid}`);
  // buildHarness is async; this command is invoked from an async main.
  return buildHarness({ repoRoot: repoRoot(), harnessName, outDir }).then(({ manifest }) => {
    const written = applyDistribution({ distributionDir: outDir, projectRoot: root, manifest });
    saveConfig(root, { harness: harnessName });
    scaffoldMemory(root);
    if (flags.json) {
      printJson({ harness: harnessName, projectRoot: root, written, nextStep: manifest.configNextStep });
      return;
    }
    process.stdout.write(`${green("PASS")} configured ${bold(manifest.productName)} in ${root}\n`);
    process.stdout.write(`  Wrote: ${written.join(", ")}\n`);
    process.stdout.write(`  Next:  ${manifest.configNextStep}\n`);
  });
}

function scaffoldMemory(root) {
  const source = join(engineRoot(), "memory");
  if (!existsSync(source)) return;
  mkdirSync(memoryDir(root), { recursive: true });
  for (const file of readdirSync(source)) {
    const target = join(memoryDir(root), file);
    if (file.endsWith(".md") && !existsSync(target)) copyFileSync(join(source, file), target);
  }
}

function cmdInit(flags) {
  const root = resolve(flags.project || process.cwd());
  mkdirSync(workspaceRoot(root), { recursive: true });
  scaffoldMemory(root);
  if (!existsSync(configPath(root))) saveConfig(root, { harness: detectHarness(root) });
  process.stdout.write(`${green("PASS")} workspace ready at ${workspaceRoot(root)}\n`);
}

function cmdStatus(flags) {
  const root = process.cwd();
  const report = statusReport(root, methodology(), loadConfig(root));
  if (flags.json) {
    printJson(report);
    return;
  }
  if (!report.active) {
    process.stdout.write(`${yellow("No active workflow.")} Start one with "my-aidlc orchestrate next \\"<description>\\"".\n`);
    return;
  }
  process.stdout.write(`${heading("Active workflow")}\n\n`);
  process.stdout.write(`  Intent:  ${bold(report.intent.id)}\n`);
  process.stdout.write(`  Scope:   ${report.scope}\n`);
  process.stdout.write(`  Stage:   ${report.currentStage || dim("(complete)")}\n`);
  if (report.parked) process.stdout.write(`  ${yellow("Parked")}\n`);
  process.stdout.write("\n");
  for (const stage of report.stages) {
    const marker =
      stage.status === "complete" || stage.status === "skipped"
        ? green("✓")
        : stage.slug === report.currentStage
          ? cyan("▶")
          : dim("·");
    process.stdout.write(`  ${marker} ${stage.phase.padEnd(9)} ${stage.name} ${dim(`(${stage.status})`)}\n`);
  }
}

function cmdList(positionals, flags) {
  const what = positionals[0] || "phases";
  const m = methodology();
  const data =
    what === "phases"
      ? m.phases.map(({ slug, name, order, focus, aiRole }) => ({ slug, name, order, focus, aiRole }))
      : what === "stages"
        ? m.stages.map(({ slug, name, phase, execution, leadAgent, produces }) => ({
            slug,
            name,
            phase,
            execution,
            leadAgent,
            produces,
          }))
        : what === "scopes"
          ? m.scopes.map(({ name, depth, description, phases }) => ({ name, depth, description, phases }))
          : what === "agents"
            ? m.agents.map(({ slug, displayName, tier, description }) => ({
                slug,
                displayName,
                tier,
                description,
              }))
            : null;
  if (!data) fail(`Unknown list target "${what}". Use phases, stages, scopes, or agents.`);
  if (flags.json) {
    printJson(data);
    return;
  }
  for (const row of data) {
    if (what === "phases") process.stdout.write(`${row.order}. ${bold(row.name)} (${row.slug}) — ${row.focus} — ${row.aiRole}\n`);
    else if (what === "stages") process.stdout.write(`${row.phase.padEnd(9)} ${row.slug.padEnd(24)} ${row.leadAgent || ""}\n`);
    else if (what === "scopes") process.stdout.write(`${row.name.padEnd(10)} ${row.depth.padEnd(9)} ${row.description}\n`);
    else process.stdout.write(`${row.slug.padEnd(26)} ${row.tier.padEnd(10)} ${row.displayName}\n`);
  }
}

function cmdStage(positionals, flags) {
  const slug = positionals[0];
  if (!slug) fail("Usage: my-aidlc stage <slug>");
  const stage = methodology().stages.find((s) => s.slug === slug);
  if (!stage) fail(`Unknown stage "${slug}".`);
  if (flags.json) {
    printJson(stage);
    return;
  }
  process.stdout.write(`${heading(stage.name)} ${dim(`(${stage.slug})`)}\n`);
  process.stdout.write(`  Phase:     ${stage.phase}\n`);
  process.stdout.write(`  Execution: ${stage.execution}\n`);
  process.stdout.write(`  Lead:      ${stage.leadAgent}\n`);
  process.stdout.write(`  Supports:  ${stage.supportAgents.join(", ") || "(none)"}\n`);
  process.stdout.write(`  Produces:  ${stage.produces.join(", ")}\n`);
  process.stdout.write(`  Consumes:  ${stage.consumes.map((c) => c.artifact).join(", ") || "(none)"}\n`);
}

function cmdScope(positionals, flags) {
  const name = positionals[0];
  if (!name) {
    const m = methodology();
    if (flags.json) {
      printJson(m.scopes.map(({ name: n, depth, description }) => ({ name: n, depth, description })));
      return;
    }
    for (const scope of m.scopes) process.stdout.write(`${scope.name.padEnd(10)} ${scope.description}\n`);
    return;
  }
  const scope = scopeByName(methodology(), name);
  if (!scope) fail(`Unknown scope "${name}".`);
  const workflow = workflowForScope(methodology(), scope);
  if (flags.json) {
    printJson({ ...scope, workflow: workflow.map((s) => s.slug) });
    return;
  }
  process.stdout.write(`${heading(scope.name)} ${dim(scope.depth)}\n`);
  process.stdout.write(`  ${scope.description}\n\n`);
  process.stdout.write(`  Stages (${workflow.length}): ${workflow.map((s) => s.slug).join(", ")}\n`);
}

function cmdGraph(flags) {
  const graph = compileGraph(engineRoot());
  if (flags.json !== false) {
    printJson(graph);
  }
}

function cmdOrchestrate(positionals, flags) {
  const verb = positionals[0];
  const root = process.cwd();
  const m = methodology();
  const config = loadConfig(root);

  if (verb === "next") {
    const text = positionals.slice(1).join(" ").trim();
    const directive = runNext(root, m, config, {
      text,
      newIntent: flags["new-intent"] === true,
      scope: typeof flags.scope === "string" ? flags.scope : undefined,
      resume: flags.resume === true,
    });
    printJson(directive);
    return directive.kind === "error" ? 1 : 0;
  }
  if (verb === "report") {
    const directive = runReport(root, m, config, {
      stage: typeof flags.stage === "string" ? flags.stage : undefined,
      result: typeof flags.result === "string" ? flags.result : undefined,
      userInput: typeof flags["user-input"] === "string" ? flags["user-input"] : undefined,
      reason: typeof flags.reason === "string" ? flags.reason : undefined,
    });
    printJson(directive);
    return directive.kind === "error" ? 1 : 0;
  }
  if (verb === "park") {
    const state = loadState(root);
    if (!state) fail("No active workflow to park.");
    printJson(parkDirective(root, state));
    return 0;
  }
  fail(`Unknown orchestrate verb "${verb || ""}". Use next, report, or park.`);
  return 1;
}

function cmdDoctor(flags) {
  const report = runDoctor(process.cwd());
  if (flags.json) {
    printJson(report);
    process.exit(report.ok ? 0 : 1);
  }
  process.stdout.write(`${heading("my-aidlc doctor")}\n\n`);
  for (const check of report.checks) {
    const label = check.status === "pass" ? green("PASS") : check.status === "warn" ? yellow("WARN") : red("FAIL");
    process.stdout.write(`  ${label} ${check.message}\n`);
  }
  process.stdout.write("\n");
  process.stdout.write(report.ok ? `${green("All checks passed.")}\n` : `${red("Some checks failed.")}\n`);
  process.exit(report.ok ? 0 : 1);
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

async function main() {
  const argv = process.argv.slice(2);
  const { flags, positionals } = parseArgs(argv);
  let command = positionals[0];

  // Top-level aliases.
  if (flags.version || command === "version") return cmdVersion();
  if (flags.help || command === "help" || command === undefined) return cmdHelp();
  if (flags.status || command === "--status") return cmdStatus(flags);
  if (flags.doctor || command === "doctor") return cmdDoctor(flags);

  switch (command) {
    case "config":
      return cmdConfig(flags);
    case "init":
      return cmdInit(flags);
    case "status":
      return cmdStatus(flags);
    case "list":
      return cmdList(positionals.slice(1), flags);
    case "stage":
      return cmdStage(positionals.slice(1), flags);
    case "scope":
      return cmdScope(positionals.slice(1), flags);
    case "phase": {
      const m = methodology();
      const slug = positionals[1];
      const phase = m.phases.find((p) => p.slug === slug);
      if (!phase) fail(`Unknown phase "${slug}".`);
      if (flags.json) printJson(phase);
      else process.stdout.write(`${heading(phase.name)} — ${phase.focus} — ${phase.aiRole}\n${phase.description}\n`);
      return undefined;
    }
    case "graph":
      return cmdGraph(flags);
    case "orchestrate":
      return cmdOrchestrate(positionals.slice(1), flags);
    case undefined:
      return cmdHelp();
    default:
      fail(`Unknown command "${command}". Run "my-aidlc help".`);
  }
  return undefined;
}

main()
  .then((code) => {
    if (typeof code === "number") process.exit(code);
  })
  .catch((error) => {
    process.stderr.write(`${red("ERROR")} ${error?.stack || error?.message || error}\n`);
    process.exit(1);
  });

export { parseArgs, methodology, cmdConfig };
