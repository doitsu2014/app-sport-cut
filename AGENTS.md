# AGENTS.md

Instructions for AI coding agents working in this repository. Read this file
before changing code. `core/AGENTS.md` and `app/AGENTS.md` add track-specific
detail and take precedence when you are working inside those directories.

## What this project is

Sportcut turns a badminton match recording into a polished highlight video
entirely on the user's device: import a local recording, strip the downtime,
confirm the score in a few taps, pick the best rallies, and export an edited
video. Everything runs offline — recordings and analysis results never leave the
device, and no cloud or online-API dependency may be introduced.

The product is deliberately semi-automatic. The app proposes rally boundaries
and a suggested winner; the user confirms. Do not build features that claim
fully automatic officiating — the reasoning is in `docs/architecture.md`.

## Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter / Dart 3, macOS desktop |
| Client state | Riverpod (`flutter_riverpod`) |
| Native engine | Rust workspace, edition 2021, `rust-version = 1.80` |
| Language boundary | `flutter_rust_bridge` v2, pinned to **2.13.0** |
| Media processing | `ffmpeg` / `ffprobe`, behind the `MediaToolchain` abstraction |
| Client catalog | SQLite (`sqflite`) |

## Repository map

| Path | Responsibility |
| --- | --- |
| `core/` | Rust engine: media foundation, job model, and the single FFI facade. Builds, lints, and tests with no client toolchain installed. |
| `app/` | Flutter client: match library, import, playback, and the typed bridge wrapper. |
| `models/` | Model assets and weights that ship with the app, plus the notes mapping each to its license-register entry. |
| `tools/` | Supported developer entry points: preflight, engine verification, bridge generation, engine library build, macOS run. |
| `docs/` | Architecture (`docs/architecture.md`), feature list and road map (`docs/features-roadmap.md`), external dependencies (`docs/external-dependencies.md`), data and storage models (`docs/data-storage-models.md`), verification records (`docs/verification/`). |
| `openspec/` | Change artifacts. Specs in `openspec/specs/`, active changes in `openspec/changes/`, finished ones in `openspec/changes/archive/`. |
| `flutter_rust_bridge.yaml` | Codegen configuration. Generated files are never committed. |

## The two tracks

Work is split into an **engine track** (`core/`) and a **client track** (`app/`)
that meet at the bridge. The engine must stay buildable on a machine with no
Flutter, Xcode, or JDK.

```bash
tools/preflight.sh --profile engine   # what the engine needs
tools/preflight.sh --profile macos   # what the macOS client needs
tools/preflight.sh                    # everything (default)

tools/verify-engine.sh                # cargo fmt --check, clippy, test
cd app && flutter analyze             # client static analysis

tools/generate-bridge.sh              # Dart bindings + Rust glue (not committed)
tools/build-engine-lib.sh             # core/crates/api/target/release/libsportcut_api.*
tools/run-macos.sh                    # dev run of the client on macOS
```

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

The exception is an explicit request to verify, close, or archive an OpenSpec
change: that workflow requires recorded evidence, so run `tools/verify-engine.sh`
and/or `flutter test` in `app/` at that point (see "OpenSpec workflow" below).

## Conventions

### Rust engine (`core/`)

- Workspace lints are enforced from `core/Cargo.toml`: `unsafe_code = "deny"`,
  `clippy::dbg_macro = "deny"`, `clippy::todo = "deny"`, and
  `missing_debug_implementations = "warn"`. Do not add `#[allow]` for these in
  hand-written code; the only exception is the generated FFI module.
- Formatting is `rustfmt` with `core/rustfmt.toml` (100-column width, Unix
  newlines). Run `cargo fmt --all` in `core/`.
- Crate boundaries mirror the pipeline stages (`common`, `media`, `storage`,
  `jobs`, `export`, `court`, `vision`, `rally`, `score`, `highlight`, `api`). Put
  new capability in the crate that owns the stage instead of widening an
  unrelated one.
- Only `sportcut-api` crosses the language boundary. Internal crates are free to
  change because the bridge only sees that facade.
- Keep everything reachable from the media pipeline free of the Flutter/Xcode
  client toolchain. Don't add a dependency that requires Xcode or the Flutter
  SDK to a shared crate; the engine builds with only Rust and ffmpeg.

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
- Talk to the engine only through `app/lib/src/bridge/sportcut_engine.dart`. Do
  not import `bridge/generated/` from feature code.

### The bridge

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

### Data and storage ownership

- The engine owns artifact files; the Flutter app owns the SQLite catalog and
  the app-owned copy of each imported recording.
- Import takes custody of a recording: the picked file is copied into
  `SportcutRecordings/<matchId>` and that copy is what the match records, because
  the platform picker may hand back a file in a directory the app does not own
  and cannot rely on. The file the user
  selected is never copied, moved, renamed, or modified — it is not ours to
  touch.
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
asset, and codec gets a row in `docs/external-dependencies.md` **before** the
change that introduces it is complete. A component that cannot ship in a
proprietary build is recorded as `not-shippable` with the specific conflict
named. GPL FFmpeg builds are not shippable — `tools/preflight.sh` flags them.
Never assume an open-source library makes the assets it carries safe to
redistribute.

## Guardrails

- No network access, telemetry, or online API in product code paths.
- No `unsafe` in hand-written Rust.
- No GPL-licensed component on a shipping path.
- No secrets, tokens, or machine-specific absolute paths committed to the repo.
- Keep `main` working: the engine builds and lints without the Flutter/Xcode client toolchain.

## Definition of done

- The requested behavior is implemented and matches the relevant spec or plan.
- Formatting and lint are clean for the track you touched.
- No generated file was hand-edited or committed.
- Any new dependency has a license-register row.
- The task checkbox in the OpenSpec change's `tasks.md` is marked complete when
  the work came from a change.

<!-- OpenSpec workflow -->
## OpenSpec workflow

Use the OpenSpec CLI and the relevant OpenSpec skill whenever work is part of a
structured change (proposing, continuing, implementing, verifying, syncing, or
archiving a change). Treat the change artifacts under `openspec/changes/` as the
source of truth for the requested behavior and implementation tasks.

- Before implementing a selected change, run `openspec status --change "<name>" --json`
  and `openspec instructions apply --change "<name>" --json`.
- Read every context file named by the apply instructions before changing code.
- Implement only the pending tasks for that change, and mark a task complete in
  its task artifact immediately after it is verified.
- If the change is ambiguous, required artifacts are missing, or implementation
  exposes a design conflict, pause and update or clarify the OpenSpec artifacts
  before proceeding.
- Verification runs are the one place the skip-tests default does not apply:
  when the user asks to verify, close, or archive a change, run the verification
  commands and record the output under `docs/verification/`.
- Run the OpenSpec verification workflow before considering a change ready to
  archive; archive only after implementation and verification are complete.
<!-- /OpenSpec workflow -->

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
