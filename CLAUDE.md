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
| Engine host | `core/service` background service over a Unix socket + JSON-RPC (ADR-0001) |
| Language boundary | Sportcut Service Protocol v1; legacy `flutter_rust_bridge` 2.13.0 remains only until Phase 5 |
| Media processing | `ffmpeg` / `ffprobe` behind the `MediaToolchain` abstraction; service-owned and required at runtime |
| Client catalog | Target: service-owned SQLite (schema v6 adopting v5). The legacy FFI client still owns v5 until Phase 4 |

## Repository map

| Path | Responsibility |
| --- | --- |
| `core/` | Rust engine: media foundation, job model, analysis crates, `core/crates/protocol`, and the `core/service` background process. Builds, lints, and tests with no client toolchain installed. |
| `app/` | Flutter client: match library, import, playback, and the legacy FFI bridge wrapper until Phase 5. |
| `models/` | Model assets and weights that ship with the app, plus the notes mapping each to its license-register entry. |
| `tools/` | Supported developer entry points: preflight, engine verification, service build/run/embed, inference assets, bridge generation, and the no-Rust guard. |
| `docs/` | Requirements (`docs/brd/`), architecture decisions (`docs/adr/`), service architecture and protocol (`docs/architecture/`). |
| `flutter_rust_bridge.yaml` | Legacy codegen configuration. Generated files are never committed; retired at Phase 5. |

## Tracks and service

Work is split into an **engine track** (`core/`), a **client track** (`app/`),
and the **service host** (`core/service`) that runs the engine in a separate
process. The engine must stay buildable on a machine with no Flutter, Xcode, or
JDK.

```bash
tools/preflight.sh --profile engine   # what the engine needs
tools/preflight.sh --profile macos    # what the macOS client needs
tools/preflight.sh                    # everything (default)

tools/verify-engine.sh                # cargo fmt --check, clippy, test
cd app && flutter analyze             # client static analysis

# Service host (ADR-0001)
tools/build-service.sh                # core/target/release/sportcut-service
tools/run-service.sh                  # dev service on a temporary state root
tools/embed-service.sh <app>          # copy/sign Contents/Helpers/SportcutService
tools/check-no-rust-in-app.sh         # FFI guard; warning mode until Phase 5

# Inference assets
tools/fetch-inference-assets.sh       # download and verify TFLite runtime + model
tools/embed-inference-assets.sh <app> # copy the runtime + model into the bundle

# Legacy FFI path (do not add new usage)
tools/generate-bridge.sh              # Dart bindings + Rust glue (not committed)
tools/build-engine-lib.sh             # core/crates/api/target/release/libsportcut_api.*
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
inference paths: `engine.tracking.start` rejects `runtimePath` and `modelPath`.
The legacy Flutter FFI path still passes them until the Phase 2 cutover.
`ffmpeg`/`ffprobe` remain required at runtime.

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

## Conventions

### Rust engine (`core/`)

- Workspace lints are enforced from `core/Cargo.toml`: `unsafe_code = "deny"`,
  `clippy::dbg_macro = "deny"`, `clippy::todo = "deny"`, and
  `missing_debug_implementations = "warn"`. Do not add `#[allow]` for these in
  hand-written code. The only permitted exceptions are the generated FFI module
  and a narrow, documented OS-glue module in `core/service` when a safe wrapper
  does not exist.
- Formatting is `rustfmt` with `core/rustfmt.toml` (100-column width, Unix
  newlines). Run `cargo fmt --all` in `core/`.
- Crate boundaries mirror the pipeline stages (`common`, `media`, `storage`,
  `jobs`, `export`, `court`, `vision`, `rally`, `score`, `highlight`, `api`,
  `protocol`). Put new capability in the crate that owns the stage instead of
  widening an unrelated one.
- Only `sportcut-api` crosses the legacy FFI boundary. The frozen client
  contract for new work is `core/crates/protocol`; `core/service` is the engine
  host.
- Keep everything reachable from the media pipeline free of the Flutter/Xcode
  client toolchain. Do not add a dependency that requires Xcode or the Flutter
  SDK to a shared crate; the engine builds with only Rust and ffmpeg.

### Background service (`core/service`)

- Target per ADR-0001: the service is a separate executable, never a dylib or
  static library linked into the Flutter app. No new Rust, `dart:ffi`,
  `flutter_rust_bridge` bindings, or `libsportcut_api.dylib` may be added. The
  legacy FFI path is the only exception and is retired at Phase 5.
- `core/crates/protocol` is the wire contract. Keep method names, framing,
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
- New engine work goes through the service protocol. The legacy FFI wrapper
  (`app/lib/src/bridge/sportcut_engine.dart`) remains for the rollback window;
  do not add new FFI calls. Do not import `bridge/generated/` from feature code.

### Legacy FFI bridge

- Generated files are **never** hand-edited and **never** committed:
  `core/crates/api/src/frb_generated.rs` and
  `app/lib/src/bridge/generated/`. Regenerate them with
  `tools/generate-bridge.sh`.
- The codegen input is `crate::dto,crate::facade`; the committed module
  declaration is in `core/crates/api/src/lib.rs` behind the `bridge` feature.
- The bridge version must match in all three places: `core/crates/api/Cargo.toml`,
  `app/pubspec.yaml`, and `tools/generate-bridge.sh`. Change them together.
- Hand-written, typed Dart wrappers live in `app/lib/src/bridge/` next to — not
  inside — the generated directory.
- The FFI path is retired by ADR-0001 Phase 5. Do not extend it.

### Data and storage ownership

- **Target per ADR-0001:** the service owns the SQLite catalog (schema v6
  adopting v5), recording custody, jobs, artifacts, and export. The Flutter
  client holds only an in-memory cache and playback.
- **Current migration state:** until Phase 3-4 land, the legacy FFI client still
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
- No `unsafe` in hand-written Rust. The only exceptions are the generated FFI
  module and a narrow, documented OS-glue module in `core/service`.
- No GPL-licensed component on a shipping path.
- No secrets, tokens, or machine-specific absolute paths committed to the repo.
- Keep `main` working: the engine builds and lints without the Flutter/Xcode
  client toolchain.
- No new Rust linked into the Flutter app; the legacy FFI path is retired at
  Phase 5, and the service is the target host.

## Definition of done

- The requested behavior is implemented and matches the relevant spec or plan.
- Formatting and lint are clean for the track you touched.
- No generated file was hand-edited or committed.
- Any new dependency has a license-register row.
- The service/app boundary is intact: no new FFI, no new Rust in the app, and no
  new client ownership of durable service state.

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
