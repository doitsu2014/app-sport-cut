// core/tools/lib/orchestrate.mjs — the workflow engine: next, report, park,
// and status directives. This is the only component that advances state.

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import {
  DEFAULT_SPACE,
  artifactDir,
  configPath,
  detectHarness,
  intentDir,
  intentsDir,
  memoryDir,
} from "./paths.mjs";
import {
  appendAudit,
  isStageComplete,
  loadState,
  newIntentId,
  labelFromDescription,
  newState,
  saveState,
  stageRecord,
} from "./state.mjs";
import { detectScope, scopeByName, workflowForScope } from "./graph.mjs";
import { engineRoot } from "./version.mjs";

function recordDirRel(space, intentId) {
  return `aidlc/spaces/${space}/intents/${intentId}`;
}

function scopeForState(methodology, state, config) {
  const name = state.activeIntent?.scope || config.defaultScope || "classic";
  return (
    scopeByName(methodology, name) ||
    scopeByName(methodology, "classic") ||
    methodology.scopes[0]
  );
}

function currentWorkflow(methodology, state, config) {
  return workflowForScope(methodology, scopeForState(methodology, state, config));
}

function firstIncomplete(state, workflow) {
  return workflow.find((stage) => !isStageComplete(state, stage.slug)) || null;
}

function advance(state, workflow) {
  const index = workflow.findIndex((stage) => stage.slug === state.currentStage);
  for (let i = index + 1; i < workflow.length; i += 1) {
    if (!isStageComplete(state, workflow[i].slug)) {
      state.currentStage = workflow[i].slug;
      return state.currentStage;
    }
  }
  state.currentStage = null;
  return null;
}

function scaffoldWorkspace(root, methodology) {
  mkdirSync(memoryDir(root, DEFAULT_SPACE), { recursive: true });
  const coreRoot = engineRoot();
  const memorySource = join(coreRoot, "memory");
  if (existsSync(memorySource)) {
    for (const file of readdirSync(memorySource)) {
      if (!file.endsWith(".md")) continue;
      const target = join(memoryDir(root, DEFAULT_SPACE), file);
      if (!existsSync(target)) copyFileSync(join(memorySource, file), target);
    }
  }
  if (!existsSync(configPath(root))) {
    mkdirSync(join(root, "aidlc"), { recursive: true });
    saveProjectConfig(root, {
      harness: detectHarness(root),
      defaultScope: "classic",
    });
  }
}

function saveProjectConfig(root, patch) {
  const path = configPath(root);
  let current = {};
  try {
    current = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    current = {};
  }
  const next = { ...current, ...patch };
  mkdirSync(join(root, "aidlc"), { recursive: true });
  writeFileSync(path, `${JSON.stringify(next, null, 2)}\n`, "utf8");
}

export function buildRunDirective(root, methodology, config, state, stage) {
  const phase = methodology.phases.find((p) => p.slug === stage.phase);
  const scope = scopeForState(methodology, state, config);
  const workflow = currentWorkflow(methodology, state, config);
  const harness = detectHarness(root);
  const harnessDir = harness === "claude" ? ".claude" : harness === "codex" ? ".codex" : ".pi";
  const space = state.activeIntent.space || DEFAULT_SPACE;
  const intentId = state.activeIntent.id;
  const relDir = recordDirRel(space, intentId);

  const producePaths = stage.produces.map(
    (artifact) => `${relDir}/${stage.phase}/${stage.slug}/${artifact}.md`,
  );

  const consumes = [];
  const consumesAbsent = [];
  for (const entry of stage.consumes) {
    const producing = methodology.stages.find((s) => s.produces.includes(entry.artifact));
    let path = null;
    if (producing) {
      path = `${relDir}/${producing.phase}/${producing.slug}/${entry.artifact}.md`;
    }
    if (path && existsSync(join(root, path))) {
      consumes.push({ artifact: entry.artifact, path, required: entry.required });
    } else {
      consumesAbsent.push({
        artifact: entry.artifact,
        required: entry.required,
        expected: producing ? !workflow.some((s) => s.slug === producing.slug) : false,
      });
    }
  }

  const protocolModules = ["stage-protocol", "question-flow"];
  if (scope.learnings === "on") protocolModules.push("learnings");

  const stageIndex = workflow.findIndex((s) => s.slug === stage.slug) + 1;

  return {
    kind: "run-stage",
    stage: stage.slug,
    stage_name: stage.name,
    phase: stage.phase,
    phase_name: phase ? phase.name : stage.phase,
    scope: scope.name,
    stage_file: `${harnessDir}/phases/${stage.phase}/stages/${stage.slug}.md`,
    lead_agent: stage.leadAgent,
    lead_agent_file: stage.leadAgent ? `${harnessDir}/agents/${stage.leadAgent}.md` : null,
    support_agents: stage.supportAgents,
    support_agent_files: stage.supportAgents.map((agent) => `${harnessDir}/agents/${agent}.md`),
    mode: stage.mode,
    reviewer: stage.reviewer,
    reviewer_file: stage.reviewer ? `${harnessDir}/agents/${stage.reviewer}.md` : null,
    gate: true,
    workspace_requires: stage.workspaceRequires,
    produces: stage.produces,
    produce_paths: producePaths,
    consumes,
    consumes_absent: consumesAbsent,
    memory_path: scope.learnings === "on"
      ? `${relDir}/${stage.phase}/${stage.slug}/memory.md`
      : null,
    protocol_modules: protocolModules,
    record_dir: relDir,
    narration: `Running ${phase ? phase.name : stage.phase} / ${stage.name}.`,
    workflow: { scope: scope.name, stage_index: stageIndex, stage_total: workflow.length },
  };
}

function gateDirective(root, methodology, config, state, stage) {
  return {
    kind: "ask",
    ask_type: "stage-approval",
    stage: stage.slug,
    stage_name: stage.name,
    phase: stage.phase,
    scope: state.activeIntent.scope,
    question: `Approve ${stage.name}?`,
    options: ["Approve", "Request Changes"],
    route: "report",
    record_dir: recordDirRel(
      state.activeIntent.space || DEFAULT_SPACE,
      state.activeIntent.id,
    ),
  };
}

export function currentDirective(root, methodology, config, state) {
  const workflow = currentWorkflow(methodology, state, config);
  if (!state.currentStage) {
    const next = firstIncomplete(state, workflow);
    if (!next) return doneDirective(state, workflow);
    state.currentStage = next.slug;
  }
  const stage = workflow.find((s) => s.slug === state.currentStage);
  if (!stage) {
    const next = firstIncomplete(state, workflow);
    if (!next) return doneDirective(state, workflow);
    state.currentStage = next.slug;
    return currentDirective(root, methodology, config, state);
  }
  const record = stageRecord(state, stage.slug);
  if (record.status === "awaiting-approval") {
    return gateDirective(root, methodology, config, state, stage);
  }
  if (record.status === "pending") {
    record.status = "active";
    record.attempt = (record.attempt || 0) + 1;
    record.updatedAt = new Date().toISOString();
    appendAudit(root, {
      event: "STAGE_STARTED",
      space: state.activeIntent.space || DEFAULT_SPACE,
      intent: state.activeIntent.id,
      phase: stage.phase,
      stage: stage.slug,
    });
    saveState(root, state);
  }
  return buildRunDirective(root, methodology, config, state, stage);
}

function doneDirective(state, workflow) {
  return {
    kind: "done",
    message: `Workflow complete for intent "${state.activeIntent.id}" (${state.activeIntent.scope}).`,
    summary: {
      intent: state.activeIntent.id,
      scope: state.activeIntent.scope,
      stages: workflow.map((stage) => ({
        slug: stage.slug,
        name: stage.name,
        phase: stage.phase,
        status: state.stages[stage.slug]?.status || "pending",
      })),
    },
  };
}

export function parkDirective(root, state) {
  state.parked = true;
  saveState(root, state);
  appendAudit(root, {
    event: "WORKFLOW_PARKED",
    space: state.activeIntent.space || DEFAULT_SPACE,
    intent: state.activeIntent.id,
    stage: state.currentStage,
  });
  return {
    kind: "parked",
    stage: state.currentStage,
    message: `Workflow parked at ${state.currentStage}. Resume with "my-aidlc orchestrate next --resume".`,
  };
}

/** Handle `orchestrate next`. */
export function runNext(root, methodology, config, options = {}) {
  const state = loadState(root);
  const text = options.text || "";
  const forceNew = options.newIntent === true;

  if (!state || forceNew) {
    if (!text) {
      return {
        kind: "error",
        message:
          "No active workflow. Describe what you want to build, for example: my-aidlc orchestrate next \"Build a REST API for inventory\".",
      };
    }
    scaffoldWorkspace(root, methodology);
    const scopeName = options.scope || detectScope(methodology, text, config.defaultScope);
    const scope = scopeByName(methodology, scopeName) || scopeByName(methodology, "classic");
    const existing = existsSync(intentsDir(root, DEFAULT_SPACE))
      ? readdirSync(intentsDir(root, DEFAULT_SPACE))
      : [];
    const label = labelFromDescription(text);
    const id = newIntentId(label, existing);
    const intent = {
      id,
      label,
      description: text,
      scope: scope.name,
      space: DEFAULT_SPACE,
      createdAt: new Date().toISOString(),
    };
    mkdirSync(intentDir(root, intent.id, DEFAULT_SPACE), { recursive: true });
    const fresh = newState({ intent, scope: scope.name });
    appendAudit(root, {
      event: "INTENT_CREATED",
      space: DEFAULT_SPACE,
      intent: id,
      scope: scope.name,
    });
    appendAudit(root, {
      event: "SCOPE_SELECTED",
      space: DEFAULT_SPACE,
      intent: id,
      scope: scope.name,
    });
    saveState(root, fresh);
    return currentDirective(root, methodology, config, fresh);
  }

  if (state.parked && !options.resume) {
    return {
      kind: "parked",
      stage: state.currentStage,
      message: `Workflow parked at ${state.currentStage}. Resume with "my-aidlc orchestrate next --resume".`,
    };
  }
  if (state.parked && options.resume) {
    state.parked = false;
    saveState(root, state);
  }

  return currentDirective(root, methodology, config, state);
}

/** Handle `orchestrate report`. */
export function runReport(root, methodology, config, options = {}) {
  const state = loadState(root);
  if (!state) {
    return { kind: "error", message: "No active workflow to report against." };
  }
  const slug = options.stage || state.currentStage;
  const stage = methodology.stages.find((s) => s.slug === slug);
  if (!stage) {
    return { kind: "error", message: `Unknown stage "${slug}".` };
  }
  const workflow = currentWorkflow(methodology, state, config);
  if (!workflow.some((s) => s.slug === slug)) {
    return { kind: "error", message: `Stage "${slug}" is not in the "${state.activeIntent.scope}" workflow.` };
  }
  const record = stageRecord(state, slug);
  const result = options.result;
  const space = state.activeIntent.space || DEFAULT_SPACE;
  const baseAudit = {
    space,
    intent: state.activeIntent.id,
    phase: stage.phase,
    stage: slug,
    result,
    userInput: options.userInput || null,
    reason: options.reason || null,
  };

  switch (result) {
    case "in-progress":
      record.status = "active";
      break;
    case "awaiting-approval":
      record.status = "awaiting-approval";
      appendAudit(root, { ...baseAudit, event: "STAGE_AWAITING_APPROVAL" });
      break;
    case "approved":
      record.status = "complete";
      appendAudit(root, { ...baseAudit, event: "STAGE_APPROVED" });
      advance(state, workflow);
      break;
    case "completed":
      record.status = "complete";
      appendAudit(root, { ...baseAudit, event: "STAGE_COMPLETED" });
      advance(state, workflow);
      break;
    case "rejected":
      record.status = "active";
      record.feedback = record.feedback || [];
      record.feedback.push({ at: new Date().toISOString(), reason: options.reason || "" });
      appendAudit(root, { ...baseAudit, event: "STAGE_REJECTED" });
      break;
    case "revised":
      record.status = "awaiting-approval";
      appendAudit(root, { ...baseAudit, event: "STAGE_REVISED" });
      break;
    case "skipped":
      if (!options.reason) {
        return { kind: "error", message: `Reporting "skipped" for ${slug} requires a --reason.` };
      }
      record.status = "skipped";
      appendAudit(root, { ...baseAudit, event: "STAGE_SKIPPED" });
      advance(state, workflow);
      break;
    default:
      return {
        kind: "error",
        message: `Unknown report result "${result}". Valid: in-progress, awaiting-approval, approved, rejected, revised, completed, skipped.`,
      };
  }

  record.updatedAt = new Date().toISOString();
  saveState(root, state);

  const directive = currentDirective(root, methodology, config, state);
  if (directive.kind === "done") {
    appendAudit(root, { event: "WORKFLOW_COMPLETED", space, intent: state.activeIntent.id });
  }
  return directive;
}

export function statusReport(root, methodology, config) {
  const state = loadState(root);
  if (!state) {
    return { active: false, message: "No active workflow." };
  }
  const workflow = currentWorkflow(methodology, state, config);
  return {
    active: true,
    parked: state.parked,
    intent: state.activeIntent,
    currentStage: state.currentStage,
    scope: state.activeIntent.scope,
    stages: workflow.map((stage) => ({
      slug: stage.slug,
      name: stage.name,
      phase: stage.phase,
      status: state.stages[stage.slug]?.status || "pending",
    })),
  };
}
