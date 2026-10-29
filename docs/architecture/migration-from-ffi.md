# Migration from FFI to the background service

| Field | Value |
| --- | --- |
| Status | Partially executed — see [Where this stands](#where-this-stands) |
| Date | 2026-10-29 |
| Decision | [ADR-0001](../adr/0001-rust-background-service.md) |
| Engine layering | [ADR-0002](../adr/0002-clean-architecture-engine.md) |
| Target architecture | [Background service architecture](background-service.md) |
| Layering design | [Engine layering](layering.md) |
| Wire contract | [Sportcut Service Protocol v1](protocol.md) |
| Requirements | [Product context](../brd/00-product-context.md) |

This is the phased plan for replacing the in-process FFI transport with the
Sportcut background service. It is deliberately not a big-bang rewrite. Each
phase has an observable exit gate, a rollback path, and a test strategy. No
product behavior changes: the 17 facade calls, one heavy job at a time, one job
per match, progress, cancellation, checkpoints, artifacts, and errors keep
their semantics.

The Rust workspace is organised into the Clean Architecture layer directories
decided by [ADR-0002](../adr/0002-clean-architecture-engine.md): `core/entities/`,
`core/use-cases/`, `core/gateways/`, `core/adapters/`, and `core/drivers/`.
Every path in this plan names the layer directory the crate belongs in.
`tools/check-layering.sh` enforces the dependency rule, the entity purity rule,
and the single declared adapter-to-adapter exception.

## Where this stands

Phases 0, 1, 2, and 5 are done. What remains is ownership and packaging, not
transport.

| Phase | State | Note |
| --- | --- | --- |
| 0 — contract and guardrails | **Done** | Protocol crate, conformance corpus, layering gate, no-Rust guard |
| 1 — service engine parity | **Done** | All 17 engine methods over the protocol, conformance and transport tests |
| 2 — client cutover | **Done** | `app/lib/src/bridge/protocol_client.dart` speaks the protocol; the client links no Rust |
| 3 — recording custody | Not started | The client still holds its own copy of a recording |
| 4 — catalog migration | Not started | The client still owns the v5 SQLite catalog |
| 5 — FFI removal | **Done** | No `flutter_rust_bridge`, no generated bindings, no `cdylib`/`staticlib`, no bundled Rust; the guard is blocking |
| 6 — packaging and supervision | Not started | The client does not launch the service; development starts it by hand |
| 7 — hardening | Not started | |

Two consequences worth stating plainly:

- **The client transport is unverified in this repository.** The Dart client has
  no toolchain here, so it has not been analysed or run. Treat Phase 2 as
  implemented and unproven until `flutter analyze` and a live session against
  `tools/run-service.sh` pass.
- **Packaged supervision is still Phase 6.** Until it lands, a packaged app has
  no service to talk to; the endpoint must be supplied by the environment.

The phase bodies below are kept as written: they are the plan that produced the
current state, and the phases still marked "not started" are still the work.

## 1. Current state versus target

### 1.1 Current state at baseline `1541c64`

| Area | Current implementation |
| --- | --- |
| Transport | `libsportcut_api.dylib` loaded in-process through `flutter_rust_bridge` 2.13.0 |
| Rust boundary | `core/adapters/api` compiles `cdylib`, `staticlib`, and `rlib`; the `bridge` feature compiles generated `frb_generated.rs` |
| Generated code | `core/adapters/api/src/frb_generated.rs` and `app/lib/src/bridge/generated/`, never committed |
| Dart wrapper | `app/lib/src/bridge/sportcut_engine.dart`, `RustLib.init`, `ExternalLibrary.open` |
| Client catalog | `app/lib/src/features/library/data/match_catalog.dart`, SQLite schema v5, five migrations, seven tables |
| Catalog access | `editing_store.dart` plus `match_repository.dart` write directly with `sqflite` |
| Recording custody | `app/lib/src/features/library/data/recording_store.dart`, `SportcutRecordings/<matchId>` |
| Artifact roots | `app/lib/src/features/library/data/match_paths.dart`, `SportcutMatches/<matchId>` and `SportcutRecordings/<matchId>` under the documents directory |
| Build scripts | `tools/generate-bridge.sh`, `tools/build-engine-lib.sh`, `tools/embed-engine-lib.sh` |
| Xcode | Runner shell phase calls `embed-engine-lib.sh` into `Contents/Frameworks` |
| Entitlements | Debug: sandbox off, network server on; Release: sandbox on, user-selected read-only |
| Job model | `core/use-cases/jobs` registry/session/checkpoint plus the `core/adapters/api/src/jobs.rs` store |
| Errors | `SportcutError` variants converted to `anyhow`, wrapped by `SportcutEngineException` |

The transport and client rows are the baseline. The Rust paths are the current
layout: the workspace has already moved to the layer directories and the
layering check is green.

### 1.2 Target state

| Area | Target implementation |
| --- | --- |
| Transport | Unix domain socket primary; XPC fallback; JSON frames |
| Rust boundary | `core/adapters/api` is an `rlib`; the service and the FFI adapter map into the application crate `core/use-cases/engine`; no FFI after Phase 5 |
| Service | `core/adapters/service` binary owns engine, catalog, custody, jobs, export |
| Engine layering | The engine is organised per ADR-0002 as Clean Architecture layers: `core/entities/`, `core/use-cases/`, `core/gateways/`, `core/adapters/`, `core/drivers/`. Source dependencies point inward; entities stay pure; the only adapter-to-adapter edge is the declared `sportcut-service` → `sportcut-api` exception, retired at Phase 5 |
| Layering check | `tools/check-layering.sh` runs first in `tools/verify-engine.sh`; it derives each crate's layer from its directory and fails on an outward dependency, an impure entity, or an undeclared adapter edge |
| Generated code | No FRB; protocol models are versioned and tested |
| Dart client | `app/lib/src/protocol/` typed client; no `dart:ffi`, no generated bindings |
| Client catalog | In-memory cache only; no SQLite in the client |
| Catalog | Service-owned `catalog.sqlite`, schema v6 adopting v5 |
| Recording custody | Service-owned `recordings/<matchId>` with atomic copy |
| Artifact roots | Service-owned `matches/<matchId>`, same internal layout |
| Build scripts | `tools/build-service.sh`, `tools/embed-service.sh`, `tools/check-no-rust-in-app.sh` |
| Xcode | Runner shell phase embeds the signed helper and media tools |
| Entitlements | App sandbox on; helper `inherit`; no network server |
| Job model | Same use-case crates, hosted by the service process |
| Errors | Protocol codes plus the same actionable messages |

### 1.3 Engine layering status

The layering work that ADR-0002 requires is already in place:

- **Layer directories.** Crates live under `core/entities/`, `core/use-cases/`,
  `core/gateways/`, `core/adapters/`, and `core/drivers/`. The layer of a crate
  is the directory it is in.
- **Ports are inverted.** `sportcut-media` declares the `ArtifactStore` port and
  `sportcut-jobs` declares `CheckpointStore`; both are implemented in
  `sportcut-storage`. Neither use-case crate depends on storage.
- **Entity move.** `RallySuggestions`, `StoredRallyCandidate`, and
  `SuggestionInputs` moved from storage to `sportcut-rally`.
- **One declared exception.** `core/adapters/service` depends on
  `core/adapters/api` because the use cases still live in `sportcut-api`. It is
  listed in `tools/check-layering.sh` and is removed when the use cases move to
  `core/use-cases/engine` and the service maps the protocol to that application
  crate. Phase 5 is the latest point.
- **Still open.** The application-crate extraction also waits on the second
  entity move in [layering.md](layering.md#target-state): the
  `TrackArtifact`/`TrackProvenance` and `CalibrationSave` formats move to the
  entity layer, with file I/O staying in `sportcut-storage`.
- **Unaffected driver.** `core/drivers/cli` remains the headless composition
  root and is not part of the transport migration.

## 2. Non-negotiable invariants

These must hold at every phase boundary:

1. The Flutter app never links Rust, never imports `dart:ffi`, never contains
   FRB bindings, and never ships `libsportcut_api.dylib`.
2. The 17 facade operations remain available with the same observable results.
3. One heavy job at a time and one job per match.
4. Progress is stage-labelled and never decreases within a stage.
5. Cancellation is cooperative and idempotent; cancelled output is never
   final.
6. Checkpoints survive a restart; a resumed import does not redo completed
   stages.
7. The artifact layout, manifest schema 3, checkpoint schema 1, calibration
   schema 1, tracks schema 1, and rally-suggestions schema 1 are stable.
8. User-authored catalog data survives every migration step.
9. The product path opens no network connection.
10. A rollback to the previous phase is possible until the FFI removal gate.
11. The engine obeys the ADR-0002 dependency rule: no crate depends on a higher
    layer, no entity performs I/O, and the only declared adapter-to-adapter edge
    is `sportcut-service` → `sportcut-api` until Phase 5.

## 3. Phased plan

Indicative effort is 12–16 engineer-weeks, with Phases 5 and 6 overlapping.
The dates are planning aids, not commitments.

### Phase 0 — Baseline, contract, and guardrails (about 1 week)

Work:

- Record the current facade behavior as a corpus: request/response DTO
  fixtures for all 17 calls, including error cases, progress sequences, and
  cancellation outcomes. Store them under
  `core/gateways/protocol/tests/corpus/`.
- Add the protocol crate skeleton (`core/gateways/protocol`) with the v1
  message types, JSON schema, and a conformance test harness.
- Add the service binary skeleton (`core/adapters/service`) with `service.hello`,
  `service.health`, `service.ping`, and the Unix-socket transport. It serves no
  engine methods yet.
- Add `tools/check-no-rust-in-app.sh`. In this phase it runs in warning mode
  with a checked-in baseline allowlist, so CI stays green while the old FFI
  path still exists. The allowlist is deleted at Phase 5.
- Add `tools/check-layering.sh` and wire it as the first step of
  `tools/verify-engine.sh`. It reads `cargo metadata --no-deps`, derives each
  crate's layer from its directory (`entities/`, `use-cases/`, `gateways/`,
  `adapters/`, `drivers/`), and fails on an outward dependency, an impure
  entity (`std::fs`, `std::process`, `std::env`, `std::net`), or an undeclared
  adapter-to-adapter edge. The only declared edge is
  `sportcut-service` → `sportcut-api`; it is removed at Phase 5.
- Add a protocol client skeleton in `app/lib/src/protocol/` with framing,
  correlation, and a fake-server test.
- Freeze the v1 method names, frame size, error codes, and DTO naming rules.

Exit gate:

- ADR-0001 approved.
- `service.hello`, `service.health`, and `service.ping` pass over a real Unix
  socket from a Dart test.
- The fixture corpus is committed and reproducible.
- The guardrail script reports the known FFI debt but passes.
- `tools/check-layering.sh` is green and runs first in
  `tools/verify-engine.sh`; its declared-exception list names exactly the
  `sportcut-service` → `sportcut-api` edge and its removal condition.

Rollback:

- None needed; the FFI path is untouched and remains the only product path.

**Phase 0 status note (2026-10-29).** The layering gate is in place and runs
first in `tools/verify-engine.sh`. The gateway inversions are complete:
`sportcut-media` declares `ArtifactStore` and `sportcut-jobs` declares
`CheckpointStore`, both implemented by `sportcut-storage`; neither use-case
crate depends on storage. `RallySuggestions`, `StoredRallyCandidate`, and
`SuggestionInputs` now live in `sportcut-rally`. The only declared
adapter-to-adapter edge is `sportcut-service` → `sportcut-api`.

### Phase 1 — Service engine parity (about 2–3 weeks)

Work:

- Implement the 17 `engine.*` methods in the service by calling the existing
  `sportcut-api` facade. Do not reimplement engine logic in the service. The
  service reaches the use cases through `sportcut-api`; that dependency is the
  one declared adapter-to-adapter exception in ADR-0002 and in
  `tools/check-layering.sh`, and no other adapter edge is permitted.
- Move the `core/adapters/api/src/jobs.rs` store semantics into the service
  process unchanged: one heavy job, one per match, retained finished jobs,
  `job_status` with checkpointed stages. The store itself belongs in the
  application layer; see §7.2 for its final location in
  `core/use-cases/engine`.
- Add the Dart `ProtocolMediaEngine` implementing the existing `MediaEngine`
  interface.
- Add a compile-time transport switch:
  `--dart-define=SPORTCUT_TRANSPORT=ffi|service`. Default stays `ffi` in this
  phase.
- Build the parity harness: replay the Phase 0 corpus over both transports and
  compare results, including error strings and progress sequences.
- Implement idempotency for start calls and catalog mutations.

Exit gate:

- All 17 engine methods have protocol conformance tests.
- The parity corpus is equal across FFI and service for happy paths, invalid
  input, job rejection, cancellation, and toolchain failure.
- A service crash during a job leaves the same checkpoint and non-final
  artifact state as an FFI panic path.
- The app still ships the dylib and still defaults to FFI.
- The layering check remains green with no exception beyond
  `sportcut-service` → `sportcut-api`.

Rollback:

- Set `SPORTCUT_TRANSPORT=ffi`. No data has moved.

**Phase 1 status note (2026-10-29).** The service now hosts the media and vision
runtime configuration: `--ffmpeg`/`--ffprobe` and
`--tflite-library`/`--person-model`, bundle-then-environment resolution for the
inference assets, a service-owned-asset rule that rejects client-supplied
`runtimePath`/`modelPath` on `engine.tracking.start`, and a `vision` block in
`service.health`. This is the server half of the phase. The Dart
`ProtocolMediaEngine`, the transport switch, and the parity harness are not in
place, so the Flutter client still uses the FFI path and the FFI removal
checklist remains pending. The workspace already builds in the layer
directories, and the layering check admits only the declared service → API
edge.

### Phase 2 — Engine cutover in the client (about 1–2 weeks)

Work:

- Make `service` the default transport in development and release builds.
- Replace `SportcutEngine.initialize()` in `main.dart` with
  `ProtocolClient.connect()` and service supervision.
- Keep the FFI wrapper code behind the switch for the rollback window, but do
  not initialize `RustLib` on the service path.
- Implement reconnect, retry with backoff, and a labelled service-unavailable
  state.
- Map protocol errors to the existing `MatchImportException` and
  `SportcutEngineException` presentation, preserving user-facing messages.
- Run the client test suite against a fake protocol server.

Exit gate:

- 100% of engine calls in the app go through the protocol.
- `RustLib.init` is not executed on the default path.
- Widget and repository tests pass with no native library.
- A kill-and-relaunch test recovers the UI and reports `job_not_found`
  actionably.
- The feature flag back to FFI is exercised in CI.

Rollback:

- Flip the default to `ffi`; the dylib is still embedded.

### Phase 3 — Recording custody migration (about 2 weeks)

Work:

- Add `core/adapters/service/src/recordings.rs` with the existing custody rules:
  streamed copy, `.part` file, fsync, rename, remove-on-cancel, sanitized name,
  no-space classification, source read-only, startup orphan sweep.
- Add `library.match.import`, `library.match.adopt`,
  `library.recording.path`, and `library.recording.available`.
- Add `library.catalog.adoptLegacy` support for existing `SportcutRecordings`
  trees: copy-first, digest check, idempotent, and (from this phase) a job with
  stages, progress, cancellation, and a resumable checkpoint. In Phase 3 it
  copies recordings and artifacts and returns the adopted match ids with their
  new paths; the client rewrites its own catalog paths. The catalog stage
  completes in Phase 4, when the service owns the catalog.
- Add the temporary provisional-match registry (matchId → recording path) so
  `library.recording.path` and `library.recording.available` work before the
  service catalog exists. It is deleted at Phase 4.
- Wire the app's import controller to the service. The picker stays in the
  client; the file handoff uses one proven mechanism: a security-scoped
  bookmark if the Q-2 sandbox spike passes, otherwise the first-class inbox
  handoff from
  [background-service.md](background-service.md#83-sandbox-file-handoff). Do
  not ship both.
- **Interim catalog ownership (explicit).** The catalog does not move until
  Phase 4. In the Phase 3 build the service owns the recording store and
  returns a provisional `matchId`; the client still owns `MatchCatalog` and
  writes the provisional match row through its existing repository. This is one
  writer per store, not a dual write: the service writes recordings, the client
  writes catalog rows. `library.match.get` returns `null` for a provisional
  match on a Phase 3 build, and the client reads from its own catalog. Phase 4
  adopts the provisional rows and removes the client write.
- Playback reads `library.recording.path`; the client no longer constructs
  recording paths.
- Keep the Dart `RecordingStore` behind `SPORTCUT_CUSTODY=app` for rollback.

Exit gate:

- All imports copy through the service; the client writes no recording bytes
  except the documented inbox handoff, which is digest-verified by the service
  and deleted after custody. If the bookmark path is the one shipped, the
  client writes no recording bytes at all.
- Cancelled, failed, disk-full, and duplicate-import cases match the current
  behavior, including "nothing partial left behind".
- The Phase 3 build has exactly one catalog writer, the client, and the
  service has no catalog database.
- Existing recordings are adopted with a digest check and remain playable.
- `SPORTCUT_CUSTODY=app` still works for rollback.
- The source file is verified unchanged by digest after import.
- The adoption job survives a forced kill, resumes from its checkpoint, and a
  second call with the same key returns the same job.

Rollback:

- Switch custody back to the app. Recordings were copied, not moved; the
  legacy directory still holds the originals.

### Phase 4 — Catalog migration (about 3–4 weeks)

Work:

- Add `core/adapters/service/src/catalog/` with a SQLite connection, WAL mode,
  busy timeout, `PRAGMA foreign_keys = ON`, and the existing v5 tables and
  indexes. The pragma is required: the v5 schema depends on cascade and
  `SET NULL`.
- Implement fresh v6 creation and the v5 → v6 adoption migration: add
  `catalog_meta`, keep every existing table/column/index and all row values.
- Adopt the Phase 3 provisional match rows the client wrote, then flip the
  single writer to the service. The client stops writing the catalog when
  `SPORTCUT_CATALOG=service` becomes the default; there is never a build in
  which both sides write catalog rows.
- Port `EditingStore` semantics into typed Rust modules:
  - rallies: update-then-insert, delete detaches clips, delete decisions;
  - suggestion decisions: accepted and dismissed, generation-scoped;
  - clips: save, delete, transactional reorder;
  - score events: transactional replace, derived summaries;
  - export settings: one row per match;
  - workspaces and matches: list, create, update, delete with cascade.
- Implement the `library.*` methods in [protocol.md](protocol.md#8-method-table-catalog-and-recording-custody).
- Add a one-time legacy adoption path from the client's
  `getDatabasesPath()/sportcut.db` into the service state root. The original
  database is copied to `backups/` and left in place.
- Implement a shadow-read comparison: the service is authoritative, the client
  opens the legacy database read-only and compares list results for a sample of
  workspaces and matches. No dual writes.
- Replace the client `MatchCatalog`, `EditingStore`, and repository writes with
  `ProtocolLibraryRepository` and an in-memory cache. Retain `sqflite` only
  behind `SPORTCUT_CATALOG=dart` for rollback.

Exit gate:

- A v5 fixture database with workspaces, matches, rallies, scores, clips,
  suggestion decisions, and export settings migrates to v6 with equal row
  counts and equal values for every existing column.
- Every `library.*` method has a conformance test.
- The client performs no SQLite writes and holds no database handle on the
  default path.
- Shadow-read comparison is clean for the fixture and for a recorded
  production-like database.
- A rollback copy of the database is restorable within the window.
- Catalog operations meet the performance targets in
  [background-service.md](background-service.md#11-performance).

Rollback:

- The preferred rollback is to **restore the retained v5 backup**
  (`backups/catalog-v5-<timestamp>.sqlite`) to the legacy path during a freeze
  window. Freeze catalog writes first, then restore, then launch the Phase 3
  build. Edits made only in the service after cutover are lost unless they were
  exported; the freeze window is the contract.
- A copied-back v6 database does **not** open in the v5 client. `MatchCatalog`
  opens with `version: 5` and no `onDowngrade`, so SQLite throws when
  `PRAGMA user_version` is 6. If the service database must be reused, stop all
  writers, checkpoint and close WAL (`-wal`/`-shm`), run
  `PRAGMA user_version = 5`, verify the table set and row counts, and only then
  point the client at it. This is a documented recovery step, not a supported
  automatic downgrade.
- The migration test covers both rollback paths: backup restore and the
  user_version reset with WAL present.
- The `catalog_meta` table is additive and ignored by a v5 client, but that
  does not make the database openable without the `user_version` reset.

### Phase 5 — FFI removal (about 1 week)

Work:

- Delete the FFI and FRB path completely. The checklist in §6 is the gate.
- Delete the `bridge` feature, `frb_generated` module, generated directories,
  and `flutter_rust_bridge.yaml`.
- Change `core/adapters/api` to an `rlib` only. Remove `cdylib` and `staticlib`.
- Remove `tools/generate-bridge.sh`, `tools/build-engine-lib.sh`, and
  `tools/embed-engine-lib.sh`.
- Remove the Xcode embed-engine phase and the development dylib loader.
- Remove `flutter_rust_bridge` and `sqflite`/`sqflite_common_ffi` from
  `pubspec.yaml` and the lockfile.
- Remove the transport feature flag and the old FFI wrapper.
- Delete the guardrail allowlist and make `tools/check-no-rust-in-app.sh`
  blocking.
- Retire the declared `sportcut-service` → `sportcut-api` exception. Move the
  use-case modules out of `sportcut-api` into the application crate
  `core/use-cases/engine` (`sportcut-engine`) and have the service map protocol
  types to it. The FFI adapter keeps the DTOs and the DTO ↔ domain conversion.
  Remove the exception from `tools/check-layering.sh` in the same change.
- Complete the second entity move from [layering.md](layering.md#target-state):
  `TrackArtifact`/`TrackProvenance` and `CalibrationSave` formats move to the
  entity layer, with file I/O staying in `sportcut-storage`.

Exit gate:

- Every item in §6 passes.
- A clean release build contains no Sportcut dylib and no FRB string.
- `otool -L` on the app and helper matches the expected lists.
- `flutter analyze` and the client tests pass with no native library.
- `tools/verify-engine.sh` passes.
- `tools/check-layering.sh` is green with an empty declared-exception list; no
  adapter depends on another adapter.

Rollback:

- Ship the previous app version. The service-owned data remains readable by the
  Phase 4 build. This is the last phase with a simple binary rollback; after
  this, the FFI path is gone.

### Phase 6 — Packaging, signing, sandbox, and distribution (about 2–3 weeks)

Work:

- Add the helper bundle layout and `Info.plist`.
- Add `tools/build-service.sh` (universal binary) and
  `tools/embed-service.sh` (copy, sign, verify).
- Update the Xcode Runner phase to call `embed-service.sh` and
  `embed-inference-assets.sh`.
- Set the app and helper entitlements from
  [background-service.md](background-service.md#9-sandbox-packaging-signing-and-notarization).
- Sign inside-out; notarize; staple; verify.
- Build the XPC fallback variant for the Mac App Store path.
- Package the media tools as signed executables resolved from the bundle.
- Run the sandbox smoke tests: import via bookmark, playback path, export,
  helper crash and relaunch.

Exit gate:

- The notarized app launches on a clean Mac with Gatekeeper.
- The helper is a separate process under the sandbox and opens no network
  socket.
- Import, playback, analysis, cancellation, and export pass in the sandboxed
  build.
- The XPC fallback build passes the same functional smoke test.
- The app contains no Rust library and no FFI residue.

Rollback:

- Ship the previous signed build. Data is forward-compatible within the
  documented catalog version.

### Phase 7 — Hardening and release (about 1 week)

Work:

- Run failure injection: kill the helper mid-import, mid-export, and
  mid-catalog-write; disconnect mid-request; fill the disk; corrupt the
  catalog; remove `ffmpeg`.
- Measure cold start, RPC latency, import throughput, and track-window bounds
  against the FFI baseline.
- Finalize diagnostics, the health view, and user-facing service errors.
- Rehearse the migration on a production-like library and a clean install.
- Update README, CLAUDE.md, and the dependency register.

Exit gate:

- No open release-blocking defect.
- Migration rehearsal passes with a measured rollback.
- Performance is within the documented targets or the deviation is accepted.
- All BRD Must requirements still pass, including NFR-9.
- The no-Rust-in-app check is green in the release job.

Rollback:

- Ship the previous signed build. Data is forward-compatible within the
  documented catalog version.

## 4. Phase summary

| Phase | Focus | Exit gate in one line | Rollback |
| --- | --- | --- | --- |
| 0 | Contract, guardrails, and layering gate | Service handshake over a real socket; corpus frozen; layering check green | None needed |
| 1 | Engine parity | All 17 calls equal over both transports | Flag to FFI |
| 2 | Client engine cutover | No `RustLib.init` on default path | Flag to FFI |
| 3 | Recording custody | Imports and playback through service; source unchanged | Flag to app custody |
| 4 | Catalog | v5 → v6 parity; no client SQLite writes | Legacy DB copy |
| 5 | FFI removal | §6 checklist green; layering exception retired | Previous app version |
| 6 | Packaging | Notarized sandboxed build passes smoke tests | Previous signed build |
| 7 | Hardening | Release gates pass | Previous signed build |

## 5. Dual-run and feature flags

### 5.1 Transport switch

- `--dart-define=SPORTCUT_TRANSPORT=ffi|service`.
- Phases 0–1: default `ffi`.
- Phase 2 onward: default `service`.
- Phase 5: the flag and the `ffi` branch are deleted.
- `SPORTCUT_FORCE_FFI=1` is a development-only escape hatch in Phases 2–4. It
  is compiled out of release builds and is not a user-facing setting.

### 5.2 Subsystem switches

- `SPORTCUT_CUSTODY=app|service` in Phase 3.
- `SPORTCUT_CATALOG=dart|service` in Phase 4.
- Each switch defaults to the old path until its phase exit gate, then to the
  new path, then is deleted.
- A switch never selects "both write". Dual writes are prohibited because
  they create two sources of truth.

### 5.3 Shadow reads, not shadow writes

- The service is authoritative during the catalog cutover.
- The client may open the legacy database read-only and compare query results
  in a diagnostics log.
- Any divergence is a defect and blocks the phase exit; it is not reconciled by
  copying rows.

### 5.4 Kill switch

- A development-only environment variable can stop the app from launching the
  service and fall back to FFI until Phase 5.
- The release build has no kill switch; a service failure surfaces an
  actionable error and a relaunch, not a silent transport change.

## 6. Complete FFI removal checklist

All items are blocking. The check script automates the mechanical ones; the
release checklist covers the rest.

| # | Item | Check | Phase |
| --- | --- | --- | --- |
| 1 | `libsportcut_api.dylib` | `find Sportcut.app -name 'libsportcut_api.*'` returns nothing | 5 |
| 2 | FRB Rust dependency | No `flutter_rust_bridge` in `core/Cargo.toml`, `core/adapters/api/Cargo.toml`, or `Cargo.lock` | 5 |
| 3 | FRB Dart dependency | No `flutter_rust_bridge` in `app/pubspec.yaml` or `pubspec.lock` | 5 |
| 4 | FRB config | `flutter_rust_bridge.yaml` deleted | 5 |
| 5 | Generated Rust glue | `core/adapters/api/src/frb_generated.rs` deleted and not regenerated | 5 |
| 6 | Generated Dart bindings | `app/lib/src/bridge/generated/` deleted | 5 |
| 7 | Dart bridge wrapper | `app/lib/src/bridge/sportcut_engine.dart` deleted or replaced by the protocol client | 5 |
| 8 | `dart:ffi` | No `import 'dart:ffi'`, `DynamicLibrary`, `ExternalLibrary`, or `RustLib` in `app/lib` | 5 |
| 9 | `bridge` feature | No `bridge` feature in `core/adapters/api/Cargo.toml`; no `#[cfg(feature = "bridge")]` | 5 |
| 10 | Crate type | `core/adapters/api/Cargo.toml` has `crate-type = ["rlib"]` only, with no `cdylib` or `staticlib`; an optional `core/adapters/xpc-bridge` `staticlib` may be linked only into the XPC target and must not add a second adapter-to-adapter edge | 5 |
| 11 | Build script | `tools/build-engine-lib.sh` deleted | 5 |
| 12 | Embed script | `tools/embed-engine-lib.sh` deleted | 5 |
| 13 | Codegen script | `tools/generate-bridge.sh` deleted | 5 |
| 14 | Xcode phase | No `embed-engine-lib.sh` in `app/macos/Runner.xcodeproj/project.pbxproj` | 5 |
| 15 | Dev loader env | No `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` in `tools/run-macos.sh` | 5 |
| 16 | Preflight text | `tools/preflight.sh` no longer reports bridge generation as a requirement | 5 |
| 17 | Entitlements | `com.apple.security.network.server` removed from Debug and Release | 5 |
| 18 | Docs and agents | README, CLAUDE.md, `app/README.md`, `core/README.md`, and `tools/README.md` describe only the service and protocol. Updated in the same change that flips the default transport (Phase 2), not only here | 2, re-checked 5 |
| 19 | CI guard | `tools/check-no-rust-in-app.sh` is blocking and has no allowlist | 5 |
| 20 | Binary inspection | `otool -L` shows no Sportcut Rust library; `nm -u` on an unstripped `ci-check` app artifact shows no `sportcut_` symbols; the `sportcut_rust_sentinel` is present in the service and absent from the app. A stripped release `nm` alone is not proof | 5–6 |
| 21 | Bundle inspection | No `Contents/Frameworks/libsportcut_api.*` and no FRB string in the app binary | 5–6 |
| 22 | Build graph | `cargo tree -p sportcut-api` has no FRB and the app build does not invoke Cargo | 5 |
| 23 | Release artifact | The notarized artifact passes all checks in a clean environment | 6 |
| 24 | Client SQLite | No `sqflite` or `sqflite_common_ffi` in `app/pubspec.yaml` or `pubspec.lock`; no legacy database handle is opened on the default path | 5 |

## 7. File-level changes

### 7.1 Rust crates and files by layer

Some rows are already present from Phases 0–1; the rest land in the phase in
§3 that needs them. Every path is under its layer directory.

| Path | Purpose |
| --- | --- |
| `core/gateways/protocol/Cargo.toml` | Wire types, version constants, error codes |
| `core/gateways/protocol/src/lib.rs` | Protocol v1 message types |
| `core/gateways/protocol/src/frame.rs` | Length-prefixed frame encoding |
| `core/gateways/protocol/src/handshake.rs` | Hello, health, ping, and capabilities |
| `core/gateways/protocol/src/method.rs` | Method names and capability table |
| `core/gateways/protocol/src/rpc.rs` | JSON-RPC subset: request, response, notification |
| `core/gateways/protocol/src/version.rs` | Major/minor negotiation and capabilities |
| `core/gateways/protocol/src/error.rs` | Code/kind mapping |
| `core/gateways/protocol/tests/conformance.rs` | Golden message tests |
| `core/gateways/protocol/tests/corpus/` | Phase 0 facade corpus |
| `core/adapters/service/Cargo.toml` | Service binary |
| `core/adapters/service/src/main.rs` | Argument parsing, state root, startup, shutdown |
| `core/adapters/service/src/lib.rs` | Service crate surface |
| `core/adapters/service/src/config.rs` | Launcher options and environment |
| `core/adapters/service/src/state_root.rs` | Layout resolution and permissions |
| `core/adapters/service/src/server.rs` | Unix listener, peer check, framing, connection lifecycle |
| `core/adapters/service/src/rpc.rs` | Dispatcher, correlation, idempotency |
| `core/adapters/service/src/methods.rs` | Method routing for `service.*`, `engine.*`, and `library.*` |
| `core/adapters/service/src/engine.rs` | 17 `engine.*` methods |
| `core/adapters/service/src/idempotency.rs` | Start-call and mutation idempotency |
| `core/adapters/service/src/paths.rs` | State-root path resolution |
| `core/adapters/service/src/error.rs` | Protocol error mapping |
| `core/adapters/service/src/catalog/mod.rs` | SQLite connection and transactions |
| `core/adapters/service/src/catalog/schema.rs` | v6 schema and indexes |
| `core/adapters/service/src/catalog/migrate.rs` | v5 adoption and future migrations |
| `core/adapters/service/src/catalog/workspaces.rs` | Workspace CRUD |
| `core/adapters/service/src/catalog/matches.rs` | Match CRUD |
| `core/adapters/service/src/catalog/editing.rs` | Rallies, decisions, clips, scores, settings |
| `core/adapters/service/src/recordings.rs` | Custody copy and deletion |
| `core/adapters/service/src/artifacts.rs` | Manifest access through the application crate |
| `core/adapters/service/src/jobs.rs` | Job admission wiring over the application crate |
| `core/adapters/service/src/security.rs` | Token, peer check, path validation |
| `core/adapters/service/src/logging.rs` | Structured local logs |
| `core/adapters/service/src/os_glue.rs` | The one documented OS-glue module (`getpeereid`, `flock`, parent PID, bookmark, `libxpc`) |
| `core/adapters/service/src/supervisor.rs` | Parent PID, idle exit, shutdown |
| `core/adapters/service/tests/*` | Transport, auth, lifecycle, catalog migration, custody |
| `core/adapters/xpc-bridge/Cargo.toml` | Optional XPC transport `staticlib` for the App Store fallback; linked only into the XPC executable |
| `core/adapters/xpc-bridge/src/lib.rs` | XPC shim over the protocol; composes the application crate, not another adapter |
| `core/use-cases/engine/Cargo.toml` | Application crate: use cases over domain types |
| `core/use-cases/engine/src/lib.rs` | Use-case entry points the service and FFI adapters map into |
| `core/use-cases/engine/src/jobs.rs` | Process-wide job store and admission moved out of `sportcut-api` |
| `core/use-cases/engine/src/` (module set) | Use-case modules moved out of `sportcut-api` (`facade`, `player_tracking_job`, `track_artifact`) |

### 7.2 Changed Rust files

| Path | Change |
| --- | --- |
| `core/Cargo.toml` | Members are the layer globs (`entities/*`, `use-cases/*`, `gateways/*`, `adapters/*`, `drivers/*`); add `sportcut-engine` under `use-cases/` and the optional `xpc-bridge` under `adapters/`. `sportcut-protocol` already sits under `gateways/` and `sportcut-service` under `adapters/`. Remove bridge-only comments; keep `unsafe_code = "deny"` with one narrow, documented exception for the OS-glue module (`os_glue`), and pin safe wrappers (`nix`, `objc2`, `objc2-foundation`). The FFI exception is not restored |
| `core/adapters/api/Cargo.toml` | Remove FRB dependency, `bridge` feature, and `cdylib`/`staticlib`; keep `rlib` |
| `core/adapters/api/src/lib.rs` | Remove `frb_generated`; keep the DTOs and conversions public for the service and XPC adapters |
| `core/adapters/api/src/facade.rs` | No product logic change; orchestration moves to `core/use-cases/engine` at Phase 5, leaving DTO ↔ domain mapping |
| `core/adapters/api/src/jobs.rs` | Move to `core/use-cases/engine/src/jobs.rs`; the process-wide store is hosted by the service with the same retention and admission semantics |
| `core/adapters/api/src/player_tracking_job.rs` | Move to `core/use-cases/engine`; keep the same job plan and admission behavior |
| `core/adapters/api/src/track_artifact.rs` | Move artifact publication to `core/use-cases/engine`; the artifact formats move to the entity layer at Phase 5, file I/O stays in `sportcut-storage` |
| `core/adapters/api/src/dto.rs` | Keep as the FFI DTO source; protocol types map to it until Phase 5 |
| `core/adapters/api/src/convert.rs` | Keep as the adapter's DTO ↔ domain mapping; it maps application and entity types to the frozen DTOs |
| `core/use-cases/media/Cargo.toml` | Declares the `ArtifactStore` port; no dependency on `sportcut-storage` (the storage crate is a dev-dependency for tests only) |
| `core/use-cases/jobs/Cargo.toml` | Declares the `CheckpointStore` port; no dependency on `sportcut-storage` (the storage crate is a dev-dependency for tests only) |
| `core/gateways/storage/Cargo.toml` | Implements both use-case ports; depends inward on `sportcut-media` and `sportcut-jobs` |
| `core/entities/rally/src/suggestions.rs` | Holds `RallySuggestions`, `StoredRallyCandidate`, and `SuggestionInputs` after the move from storage |
| `core/gateways/storage/src/rally_suggestions.rs` | Reads and writes the rally types now owned by `sportcut-rally` |

### 7.3 New Dart files

| Path | Purpose |
| --- | --- |
| `app/lib/src/protocol/client.dart` | Connection, request correlation, notifications |
| `app/lib/src/protocol/framing.dart` | 4-byte length prefix |
| `app/lib/src/protocol/service_process.dart` | Launch, supervise, reconnect, shut down |
| `app/lib/src/protocol/errors.dart` | `ServiceException` and code/kind mapping |
| `app/lib/src/protocol/models/` | v1 DTO models |
| `app/lib/src/features/library/data/protocol_library_repository.dart` | Service-backed repository |
| `app/lib/src/features/library/data/library_cache.dart` | In-memory cache and invalidation |
| `app/lib/src/features/library/data/recording_handoff.dart` | Security-scoped bookmark / inbox handoff |
| `app/test/protocol/` | Fake server and client tests |

### 7.4 Removed or replaced Dart files

| Path | Disposition |
| --- | --- |
| `app/lib/src/bridge/sportcut_engine.dart` | Removed at Phase 5; `ProtocolMediaEngine` replaces it at Phase 1–2 |
| `app/lib/src/bridge/generated/` | Removed; never committed |
| `app/lib/src/features/library/data/match_catalog.dart` | Logic moves to the service at Phase 4; the file is retained behind `SPORTCUT_CATALOG=dart` for rollback and the read-only shadow comparison, and removed at Phase 5 |
| `app/lib/src/features/library/data/recording_store.dart` | Removed at Phase 3; logic moves to the service |
| `app/lib/src/features/library/data/match_paths.dart` | Removed; service returns paths |
| `app/lib/src/features/library/data/match_repository.dart` | Replaced by the protocol repository |
| `app/lib/src/features/editing/data/editing_store.dart` | Logic moves to the service at Phase 4; retained behind `SPORTCUT_CATALOG=dart` through Phase 5, then removed |
| `app/lib/src/features/calibration/data/calibration_bridge.dart` | Becomes a protocol model mapper, or is removed if models align |
| `app/lib/src/app/di.dart` | `sportcutEngineProvider` becomes `serviceClientProvider` |

### 7.5 Tools

| Path | Change |
| --- | --- |
| `tools/generate-bridge.sh` | Deleted |
| `tools/build-engine-lib.sh` | Deleted |
| `tools/embed-engine-lib.sh` | Deleted |
| `tools/build-service.sh` | New: universal Rust service build |
| `tools/embed-service.sh` | New: copy, sign, verify helper |
| `tools/check-no-rust-in-app.sh` | New: blocking guard |
| `tools/check-layering.sh` | Existing gate: derives each crate's layer from its directory; enforces inward dependencies, entity purity, and the declared exception; runs first in `tools/verify-engine.sh` |
| `tools/verify-protocol.sh` | New: conformance and parity corpus |
| `tools/run-macos.sh` | Build the service, launch the app, no FRB env |
| `tools/preflight.sh` | Check Rust, Flutter, Xcode, signing, notarization; no bridge generation |
| `tools/verify-engine.sh` | Runs `tools/check-layering.sh` first, then fmt, clippy, and tests across the layer workspace; keeps the no-client-toolchain property |
| `tools/README.md` | Document the service workflow and the layering gate |

### 7.6 macOS packaging

| Path | Change |
| --- | --- |
| `app/macos/Runner.xcodeproj/project.pbxproj` | Replace the embed-engine phase with embed-service; add helper and media-tool copy phases |
| `app/macos/Runner/DebugProfile.entitlements` | Sandbox on; remove network server; keep user-selected read-only |
| `app/macos/Runner/Release.entitlements` | Keep sandbox; add any helper requirements |
| `app/macos/Runner/Info.plist` | Purpose string for user-selected files; helper metadata if needed |
| `app/macos/Runner/Configs/AppInfo.xcconfig` | Bundle and version identifiers for the helper |
| New `app/macos/Helper/Info.plist` | Helper bundle identity and version |

### 7.7 Client dependencies

| Dependency | Change |
| --- | --- |
| `flutter_rust_bridge` | Removed |
| `sqflite` / `sqflite_common_ffi` | Kept through Phase 4 for the `SPORTCUT_CATALOG=dart` rollback and the read-only shadow comparison; removed at Phase 5. The Phase 4 exit gate does not delete them |
| `path_provider` | Keep only if the client needs a cache or render-input path |
| `file_picker` | Keep for the open panel |
| `video_player` | Keep for playback |
| `share_plus` | Keep for the share sheet |
| `flutter_riverpod` | Keep |
| `path` | Keep if path joining is still needed; otherwise remove |

## 8. Rollback

| Phase | Rollback action | Data safety |
| --- | --- | --- |
| 0 | Not needed | No change |
| 1 | `SPORTCUT_TRANSPORT=ffi` | No data moved |
| 2 | Default `ffi`; dylib still embedded | No data moved |
| 3 | `SPORTCUT_CUSTODY=app` | Recordings were copied, not moved; legacy roots intact |
| 4 | `SPORTCUT_CATALOG=dart`; restore the retained v5 backup (preferred), or reset `PRAGMA user_version = 5` after checkpointing and closing WAL. A v6 database with `user_version = 6` does not open in a v5 client | Original v5 database retained in `backups/`; freeze catalog writes before restoring |
| 5 | Ship the previous app version | Service data remains readable by the Phase 4 build |
| 6 | Ship the previous signed build | Same catalog version |
| 7 | Ship the previous signed build | Same catalog version |

Rollback rules:

- A rollback never deletes the user's original recording.
- A rollback never deletes the v5 database or the service backup.
- After Phase 4 write cutover, catalog edits made only in the service must be
  frozen or exported before rolling back to a v5 client. The release plan
  includes a freeze window.
- A failed migration restores the backup automatically and reports
  `migration_required` rather than opening a half-migrated database.

## 9. Test strategy

### 9.1 Unit and contract

- Protocol: framing, UTF-8 validation, max frame, partial reads, unknown
  fields, unknown methods, duplicate ids, version negotiation, idempotency.
- Auth: missing token, wrong token, different UID (where testable), stale
  socket, live socket not removed.
- Errors: every `SportcutError` variant maps to the documented code and
  `userMessage`.
- Catalog: schema creation, v5 adoption, update-then-insert, cascade deletes,
  reorder transaction, score replace, settings upsert.
- Custody: streamed copy, `.part`, rename, cancel, no space, sanitized names,
  source read-only, deletion semantics.
- Layering: `tools/check-layering.sh` runs in verification and rejects an
  outward edge, an impure entity, and an undeclared adapter edge.

### 9.2 Parity

- The Phase 0 corpus is the oracle. It includes:
  - every facade call with valid input;
  - invalid input and boundary values;
  - job admission rejection;
  - cancellation before, during, and after a stage;
  - toolchain missing and media-tool failure;
  - manifest states: final, non-final, missing, original absent.
- The parity harness runs the corpus over FFI and service in Phases 1–4 and
  requires equal results. Error strings may differ only where the service adds
  a path or job context; the harness compares the code and the user message.

### 9.3 Migration

- A fixture v5 database covers all tables, nulls, foreign keys, and indexes.
- A production-like database is anonymized and replayed.
- Recording adoption is verified by SHA-256 before and after.
- The migration is run twice to prove idempotency.
- A forced failure at each step restores the backup and leaves the legacy data
  intact.
- Rollback is tested both ways: restore the v5 backup, and reset
  `PRAGMA user_version = 5` after checkpointing and closing `-wal`/`-shm`. A v5
  client must open the reset database and must fail on an unreset v6 one.

### 9.4 Client

- Protocol client tests against an in-process fake server.
- Repository tests with a fake protocol client.
- Widget tests for import, library, calibration, tracking, rally review, score,
  highlights, and export with the fake repository.
- No test loads a native library.
- A startup test covers service unavailable, slow handshake, and reconnect.

### 9.5 Failure injection

- Kill the service during import, export, catalog write, and
  `library.catalog.adoptLegacy`; verify checkpoint resume, no partial library,
  and an idempotent retry with the same key.
- Disconnect the socket mid-request and mid-notification.
- Fill the disk during custody and export.
- Corrupt the catalog and a manifest.
- Remove `ffmpeg` and make `ffprobe` fail.
- Launch two app instances and verify the single-instance lock.
- Force-quit the app and verify orphan cleanup.

### 9.6 Packaging

- Codesign verification, hardened runtime, notarization, stapling.
- Gatekeeper launch on a clean machine.
- Sandbox smoke test binds and connects on the exact default endpoint
  (`<container>/Data/run/s.sock`), asserting the path is at most 103 bytes;
  the socket directory is `0700`.
- Bookmark spike: app creates the bookmark with the bookmark entitlement, the
  helper resolves it, reads the file, verifies SHA-256, and leaves the source
  unchanged. Record the result. If it fails, run the inbox handoff test
  instead: `.part` → fsync → `.ready`, service re-hash, custody, inbox deletion.
- Sandbox smoke test for import, playback, export, and helper crash.
- XPC fallback smoke test for the chosen process graph and container mechanism.
- Bundle inspection for dylib, static archive, and FRB residue.
- Network inspection: `lsof` shows no network socket.

### 9.7 Performance

- Cold start to handshake.
- Small RPC p95.
- Manifest read and job status.
- Import copy throughput versus the current client copy.
- Track-window read and the 16 MiB bound.
- Export start latency and progress rate.

## 10. Packaging changes

### 10.1 Build flow

1. `cargo build --release --target aarch64-apple-darwin` and
   `x86_64-apple-darwin`.
2. `lipo` the two service binaries into one universal binary.
3. Build the Flutter app.
4. Copy the service to `Contents/Helpers/SportcutService`.
5. Copy the media tools to `Contents/Resources/MediaTools` or the helper's
   resources.
6. Sign media tools, helper, frameworks, and app inside-out.
7. Notarize, staple, and verify.
8. Run the no-Rust-in-app checks on the final artifact.

### 10.2 XPC fallback

- Add a separate build configuration or scheme that produces
  `Contents/XPCServices/SportcutService.xpc`.
- Pick one process graph from
  [background-service.md §9.2](background-service.md#92-fallback-mac-app-store-xpc-service):
  the Rust backend statically linked into the XPC target through the
  `core/adapters/xpc-bridge` staticlib with an App Group, or an XPC relay to
  the third helper process over the Unix socket. Record the choice and prove it
  with the sandbox smoke test.
- Add the App Group (or proven `inherit`) entitlement to the app, XPC target,
  and helper, and set the shared state root. Re-run the endpoint length check
  for the group-container path.
- Add the Swift `FlutterMethodChannel("sportcut/service")` client and the XPC
  `send`/notification interface; the Dart client's transport interface is
  unchanged.
- Keep the Rust service as the backend; the XPC shim is transport only.
- Run the same protocol conformance suite over XPC.
- Do not ship both transports in one build unless a release decision requires
  it; dual transports double the surface.

### 10.3 Media tools

- Bundle a shippable `ffmpeg`/`ffprobe` (LGPL configuration or native
  replacement, per BRD R-2 and M-3).
- Sign and notarize them with the app.
- Resolve them from the helper bundle, never from `PATH` or a developer path.
- Verify their presence at startup and report `toolchain_unavailable` with an
  actionable message.

### 10.4 Updates

- The service ships with the app. There is no independent service updater in
  v1.
- An app update replaces both binaries atomically.
- The service version is visible in `service.health`.

## 11. Risks

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- |
| R-11 | FFI-to-service migration regression: a call, error, progress, cancellation, checkpoint, or artifact behavior changes during the move | Medium | High | Phase 0 corpus; parity harness across both transports; phase exit gates; migration rehearsal; per-phase rollback; no dual writes; layering check on every engine verification | Engineering lead |
| R-12 | Catalog migration loses or rewrites user data | Low | High | Copy-first migration; backup; row-count and value equality tests; idempotency; automatic restore on failure; production-like rehearsal | Engineering lead / QA lead |
| R-13 | Protocol DTOs drift from the engine DTOs | Medium | Medium | Single protocol crate; golden messages; parity corpus; schema review in CI | Engineering lead |
| R-14 | Sandboxed file handoff fails for the security-scoped bookmark | Medium | High | Bookmark entitlement on app and helper; signed sandbox spike (create, pass, resolve, read, SHA-256, source unchanged); if it fails, first-class inbox handoff with digest verification, crash cleanup, and no second copy; Q-2; ship exactly one path | Engineering lead |
| R-15 | Playback path is unreadable in a future sandbox layout | Low | High | v1 uses a shared container; document the file-path assumption; a streamed fallback needs a new ADR | Engineering lead |
| R-16 | Service crash or orphan process leaves the UI stuck | Medium | Medium | Supervisor, parent PID, idle exit, backoff, `job_not_found` handling, checkpoint resume | Engineering lead |
| R-17 | Signing or notarization fails for the helper | Medium | High | Sign inside-out; CI signing job; clean-machine Gatekeeper test; no `disable-library-validation` | Engineering lead |
| R-18 | IPC adds noticeable latency | Medium | Medium | Performance targets; bounded payloads; progress coalescing; measure against FFI baseline | Engineering lead |
| R-19 | XPC fallback diverges from the primary transport | Medium | Medium | Same protocol payloads; shared conformance suite; one transport per build | Engineering lead |
| R-20 | Media tools cannot ship inside the signed sandboxed helper | High | High | Resolve LGPL/native backend before packaging (BRD R-2, M-3); treat as a release blocker | Legal/licensing / Engineering lead |
| R-21 | Dual-run divergence during catalog cutover | Medium | High | Shadow reads only, service authoritative; divergence blocks the exit gate; no dual writes | Engineering lead |
| R-22 | Users are surprised by the data-location change | Medium | Medium | One-time migration with backup; keep originals during the rollback window; disclosure copy; open question Q-8 | Product owner |

## 12. Definition of done

The migration is done when:

- the app and service are separate signed processes with no Rust linked into
  the app;
- the FFI removal checklist in §6 is fully green;
- the 17 facade behaviors, the job model, progress, cancellation, checkpoints,
  artifacts, and errors are covered by the parity corpus and pass;
- the catalog and recordings have migrated with verified data equality and a
  tested rollback;
- the notarized, sandboxed build passes import, playback, analysis, export,
  cancel, crash, and relaunch smoke tests;
- the XPC fallback path passes the same functional suite or is explicitly
  deferred by a recorded decision;
- the engine is organised in the ADR-0002 layer directories and
  `tools/check-layering.sh` is green with no declared exception;
- NFR-9, BR-2, NFR-4, and R-11 in the product BRD are updated and traceable to
  evidence.
