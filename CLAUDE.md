# Sportcut — Project Instructions

This is the single source of instructions for Claude Code in this repository.
It covers the Rust engine, the background service, the Flutter client, the
build tooling, and the guardrails. Read it before changing code.

## What this project is

Sportcut turns a badminton match recording into a polished highlight video
entirely on the user's device: import a local recording, strip the downtime,
confirm the score in a few taps, pick the best rallies, and export an edited
video. Everything runs offline — recordings and analysis results never leave the
device, and no cloud or online-API dependency may be introduced.

The product is deliberately semi-automatic. The app proposes rally boundaries
and a suggested winner; the user confirms. Do not build features that claim
fully automatic officiating — the reasoning is in
`docs/architecture/background-service.md` and `docs/adr/0001-rust-background-service.md`.

## Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter / Dart 3, macOS desktop |
| Client state | Riverpod (`flutter_riverpod`) |
| Native engine | Rust workspace, edition 2021, `rust-version = 1.80` |
| Engine host | `core/adapters/service` background service over a Unix socket + JSON-RPC (ADR-0001) |
| Language boundary | Sportcut Service Protocol v1 over a Unix socket. No FFI, no generated bindings, no Rust in the app |
| Media processing | `ffmpeg` / `ffprobe` behind the `MediaToolchain` abstraction; service-owned and required at runtime |
| Client catalog | Target: service-owned SQLite (schema v6 adopting v5). The client still owns its local v5 catalog until Phase 4 |

## Repository map

| Path | Responsibility |
| --- | --- |
| `core/` | Rust engine: media foundation, job model, analysis crates, `core/gateways/protocol`, and the `core/adapters/service` background process. Layered per [`docs/architecture/layering.md`](docs/architecture/layering.md). Builds, lints, and tests with no client toolchain installed. |
| `app/` | Flutter client: match library, import, playback, and the protocol client that reaches the engine. |
| `models/` | Model assets and weights that ship with the app, plus the notes mapping each to its license-register entry. |
| `tools/` | Supported developer entry points: preflight, engine verification, layering check, service build/run/embed, inference assets, bridge generation, and the no-Rust guard. |
| `docs/` | Requirements (`docs/brd/`), architecture decisions (`docs/adr/`), and the architecture set (`docs/architecture/`, indexed by its `README.md`): layering, service, protocol, and migration. |

## Tracks and service

Work is split into an **engine track** (`core/`), a **client track** (`app/`),
and the **service host** (`core/adapters/service`) that runs the engine in a separate
process. The engine must stay buildable on a machine with no Flutter, Xcode, or
JDK.

```bash
tools/preflight.sh --profile engine   # what the engine needs
tools/preflight.sh --profile macos    # what the macOS client needs
tools/preflight.sh                    # everything (default)

tools/verify-engine.sh                # cargo fmt --check, clippy, test
tools/check-layering.sh               # Clean Architecture dependency rule
tools/generate-layering-diagram.sh    # regenerate docs/architecture/layering-diagram.html
cd app && flutter analyze             # client static analysis

# Service host (ADR-0001)
tools/build-service.sh                # core/target/release/sportcut-service
tools/run-service.sh                  # dev service on a temporary state root
tools/embed-service.sh <app>          # copy/sign Contents/Helpers/SportcutService
tools/check-no-rust-in-app.sh         # blocking: no Rust/FFI in the app

# Inference assets
tools/fetch-inference-assets.sh       # download and verify TFLite runtime + model
tools/embed-inference-assets.sh <app> # copy the runtime + model into the bundle

tools/run-macos.sh                    # dev run of the legacy client on macOS
```

The service owns media-tool discovery and inference asset resolution. On macOS,
`tools/build-service.sh` enables the `macos-tflite-eval` feature by default; set
`SPORTCUT_MACOS_TFLITE_EVAL=0` to omit it, and the service then runs everything
except player tracking. The service accepts `--ffmpeg`, `--ffprobe`,
`--tflite-library`, and `--person-model`; when the inference flags are absent it
resolves the bundle files (`Contents/Frameworks/libtensorflowlite_c.dylib`,
`Contents/Resources/model.tflite`) and then `SPORTCUT_TFLITE_LIBRARY` /
`SPORTCUT_PERSON_MODEL`. The service protocol never accepts client-supplied
inference paths: `engine.tracking.start` rejects `runtimePath` and `modelPath`,
and the client never sends them. `ffmpeg`/`ffprobe` remain required at runtime.

If Flutter is not on `PATH`, set `SPORTCUT_FLUTTER_BIN` to the directory
containing the `flutter` executable before running any client-track command.

## Working agreement: implement first, tests are optional

Default to shipping implementation, not test scaffolding.

- **Do not** write new test files or add test cases unless the user explicitly
  asks for tests.
- **Do not** run the test suites as part of ordinary work. Verify your change
  with the cheapest applicable check instead — `cargo build`,
  `cargo clippy --workspace --all-targets -- -D warnings`, or
  `flutter analyze`.
- Never block a task on missing test coverage, and never mark a task blocked
  because a test does not exist.
- Touch an existing test only when your change stops it compiling, or when the
  user asks you to.

The exception is an explicit request to verify a change or a workflow that
requires recorded evidence: that workflow requires the suites, so run
`tools/verify-engine.sh` and/or `flutter test` in `app/` at that point.

## Workflows: load the skill first

When a job calls for multi-agent orchestration — fanning work out across
subagents, a review or audit sweep, a migration run in parallel, or any task that
is better structured as a Workflow script than as a sequence of direct tool
calls — **load the `workflow-authoring` skill before writing or editing the
script.** Always, not only the first time in a session.

The skill is the reference for the script API and its traps: `meta` must be a
pure literal, the pipeline-versus-barrier decision, resume semantics, the
agent/spawn patterns, and the quality patterns worth reaching for. Authoring a
workflow script from memory produces scripts that fail to parse or silently
cover less than intended.

Two things the skill does not do:

- **It does not authorise running a workflow.** The `Workflow` tool still
  requires the user's explicit opt-in — an "ultracode" session, or a request in
  the user's own words to run a workflow. Loading the skill is not permission.
- **It is not the AI-DLC orchestrator.** `/aidlc` (the block at the end of this
  file) drives the Analyze → Ideate → Develop → Launch → Curate lifecycle. That
  is a different mechanism with its own state; do not conflate the two.

For a job that does not need orchestration, skip this entirely: a handful of
direct tool calls is cheaper and easier to check than a workflow.

## Conventions

### Rust engine (`core/`)

- Workspace lints are enforced from `core/Cargo.toml`: `unsafe_code = "deny"`,
  `clippy::dbg_macro = "deny"`, `clippy::todo = "deny"`, and
  `missing_debug_implementations = "warn"`. Do not add `#[allow]` for these in
  hand-written code. The only permitted exception is a narrow, documented
  OS-glue module in `core/adapters/service` when a safe wrapper does not exist.
- Formatting is `rustfmt` with `core/rustfmt.toml` (100-column width, Unix
  newlines). Run `cargo fmt --all` in `core/`.
- Crate boundaries mirror the pipeline stages (`common`, `media`, `storage`,
  `jobs`, `export`, `court`, `vision`, `rally`, `score`, `highlight`, `api`,
  `protocol`). Put new capability in the crate that owns the stage instead of
  widening an unrelated one.
- **Dependencies point inward.** The layers are entities (`common`, `court`,
  `rally`, `score`, `highlight`), use cases (`media`, `vision`, `export`,
  `jobs`, `eval`), gateways and contracts (`storage`, `protocol`), adapters
  (`api`, `service`), and drivers (`cli`). A use case may not depend on the
  gateway that implements its port: declare the port in the use-case crate and
  implement it in `storage`. The entity layer takes no filesystem, process,
  environment, or network call. Each delivery adapter owns its own
  representation and must not borrow another adapter's. Run
  `tools/check-layering.sh` after changing a manifest; the layer map, the ports,
  and the one declared adapter exception are in
  [`docs/architecture/layering.md`](docs/architecture/layering.md), decided by
  [ADR-0002](docs/adr/0002-clean-architecture-engine.md).
- The client contract is `core/gateways/protocol`; `core/adapters/service` is
  the engine host and `sportcut-api` is the library it calls. The app links no
  Rust at all.
- Keep everything reachable from the media pipeline free of the Flutter/Xcode
  client toolchain. Do not add a dependency that requires Xcode or the Flutter
  SDK to a shared crate; the engine builds with only Rust and ffmpeg.

### Background service (`core/adapters/service`)

- The service is a separate executable, never a dylib or static library linked
  into the Flutter app. No Rust, `dart:ffi`, generated bindings, or bundled Rust
  library may be added to the app; `tools/check-no-rust-in-app.sh` fails the
  build if one appears.
- `core/gateways/protocol` is the wire contract. Keep method names, framing,
  error codes, and version negotiation stable; a change is a protocol change.
- The service owns the media toolchain and inference assets. Do not accept
  client-supplied `runtimePath`/`modelPath`.
- Keep the Unix socket only: no TCP listener, no network entitlement, 0700/0600
  permissions, peer-UID check, and the 103-byte `sun_path` guard.
- Preserve one heavy job at a time, one job per match, stage-labelled progress,
  cooperative cancellation, and checkpoint resume.

### Flutter client (`app/`)

- Lints come from `package:flutter_lints/flutter.yaml`; keep `flutter analyze`
  clean.
- Features live under `app/lib/src/features/<feature>/` with `domain/`, `data/`,
  and `presentation/` subfolders as needed, so a later phase lands inside its own
  folder instead of spreading across the app.
- Reuse the existing patterns: plain named route table in
  `app/lib/src/app/router.dart`, Riverpod providers for shared state and
  dependency injection (`app/lib/src/app/di.dart`), and the repository interface
  in `features/library/domain/`.
- The app reaches the engine only through `app/lib/src/bridge/sportcut_engine.dart`,
  which speaks the service protocol over `protocol_client.dart`. Feature code
  must not open sockets itself or hard-code protocol methods.

### Data and storage ownership

- **Target per ADR-0001:** the service owns the SQLite catalog (schema v6
  adopting v5), recording custody, jobs, artifacts, and export. The Flutter
  client holds only an in-memory cache and playback.
- **Current migration state:** until Phase 3-4 land, the client still
  owns the v5 catalog and the app-owned recording copy. Do not add new durable
  client-owned state; new work belongs in the service.
- Import takes custody of a recording: the picked file is copied into the
  service-owned recording store and that copy is what the match records. The
  file the user selected is never copied, moved, renamed, or modified — it is
  not ours to touch.
- Given a match directory, the engine writes `manifest.json`,
  `checkpoints.json`, and the `proxy/`, `audio/`, `frames/`, `calibration/`,
  `tracks/`, and `export/` subdirectories. Keep that layout stable.
- Derived media belongs outside the repository. Never point an artifact root at
  the checkout; `.gitignore` rules there are only a backstop.
- Tests and benchmarks generate their own fixtures with `ffmpeg` instead of
  committing footage.

### Developer scripts (`tools/`)

- Scripts in `tools/` are the supported entry points; keep them working from a
  clean checkout with only the tools they declare.
- They are bash with `#!/usr/bin/env bash` and `set -euo pipefail`, resolve the
  repository root from `BASH_SOURCE`, and print diagnostics to stderr.
- `preflight.sh` only reads the machine — it must install nothing and leave no
  build output behind.

### Licensing gate

Every third-party dependency, model, pretrained weight, dataset, font, audio
asset, and codec gets a row in the licensing register in
`docs/brd/00-product-context.md` **before** the change that introduces it is
complete. A component that cannot ship in a proprietary build is recorded as
`not-shippable` with the specific conflict named. GPL FFmpeg builds are not
shippable — `tools/preflight.sh` flags them. Never assume an open-source library
makes the assets it carries safe to redistribute.

## Guardrails

- No network access, telemetry, or online API in product code paths.
- No `unsafe` in hand-written Rust. The only exception is a narrow, documented
  OS-glue module in `core/adapters/service`.
- No GPL-licensed component on a shipping path.
- No secrets, tokens, or machine-specific absolute paths committed to the repo.
- Keep `main` working: the engine builds and lints without the Flutter/Xcode
  client toolchain.
- No Rust linked into the Flutter app. The service is the only engine host, and
  `tools/check-no-rust-in-app.sh` enforces it.

## Definition of done

- The requested behavior is implemented and matches the relevant spec or plan.
- Formatting and lint are clean for the track you touched.
- `tools/check-layering.sh` passes for any change to a workspace manifest or a
  crate's public surface.
- Any new dependency has a license-register row.
- The service/app boundary is intact: no FFI, no Rust in the app, and no new
  client ownership of durable service state.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**This project has a knowledge graph. Start with the code-review-graph
MCP tools to narrow scope, then read the source.** The graph is cheaper than scanning files and
gives you structural context (callers, dependents, test coverage) that file search cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

### Verify in the source

- Narrow scope with the graph, then read the source. Do not change code from graph output alone.
- For any non-trivial change, read the implementation and the relevant tests before concluding.
- Verify the exact source when touching behavior, database logic, migrations, retries, fallbacks,
  recovery, or compatibility code.
- When the graph and the source disagree, the source wins. The graph may be stale or may not
  model that relationship.
- An empty graph result can mean "not indexed" or "not statically visible", not "does not exist".

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
<!-- /code-review-graph MCP tools -->

# BEGIN my-aidlc:claude
# my-aidlc for Claude Code

This project uses **my-aidlc**, an AI-Driven Development Life Cycle workflow
engine built around five phases: **Analyze → Ideate → Develop → Launch →
Curate**.

## Start a workflow

Type `/aidlc` followed by what you want to build:

```text
/aidlc Build a REST API for inventory management
```

The workflow profile is detected from the request. You can name one explicitly:
`classic`, `express`, `feature`, `bugfix`, `mvp`, `poc`, `infra`.

## Commands

| Command | Purpose |
| --- | --- |
| `/aidlc` | Start or resume the active workflow |
| `/aidlc --status` | Show the active intent, scope, and stage |
| `/aidlc --doctor` | Validate the workspace and configuration |
| `/aidlc --version` | Print the framework version |

On the command line the same operations are available as
`my-aidlc status`, `my-aidlc doctor`, and `my-aidlc orchestrate next`.

## AI-DLC method (imported)

The method — layered practice files `org.md`, `team.md`, `project.md` — is
authored once at `aidlc/spaces/default/memory/` and pulled into Claude's
ambient context by `.claude/rules/aidlc.md`. Edit the method there, never in
the stub.

## What was installed

- `.claude/skills/aidlc/` — the orchestrator skill
- `.claude/rules/aidlc.md` — the ambient method import
- `.claude/agents/` — the 15 agent personas
- `.claude/phases/` — the five phases and their stages
- `.claude/scopes/` — the workflow profiles
- `.claude/protocols/` — stage, question, recovery, and learnings protocols
- `.claude/tools/` — the deterministic engine

## Personal overrides

Copy `.claude/settings.local.json.example` to `.claude/settings.local.json`
(gitignored) to override settings without affecting shared configuration.
# END my-aidlc:claude

<!-- rtk-instructions v2 -->
# Command output

Command output here is condensed to save tokens, keeping every signal and
dropping costly noise. Treat it as the complete result: run commands
normally, and batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output. Re-run a
command as `rtk bypass <cmd>` only when its result is unusable: empty when
output was clearly expected, contradicting its exit code, or garbled.

Delegation commands (they hand work to a cheaper model; the files never enter your context):
- `rtk bulk-read --question "..." <paths...>`
- `rtk code-write --spec "..." --reference <file> --target <file>`
<!-- /rtk-instructions -->