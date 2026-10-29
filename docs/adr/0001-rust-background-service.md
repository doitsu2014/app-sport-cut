# ADR-0001: Run the Rust backend as a separate background service

| Field | Value |
| --- | --- |
| ID | ADR-0001 |
| Title | Run the Rust backend as a separate background service |
| Status | Proposed |
| Date | 2026-10-29 |
| Deciders | Engineering lead (owner), Product owner, Security/privacy, Legal/licensing, QA lead, Design lead |
| Supersedes | The FFI transport, client-owned catalog, and client recording custody described in the product BRD and the feature BRDs. Workflow requirements remain valid; ownership and transport clauses are superseded by the transport-and-ownership notes in features 01, 02, 03, 08, and 09. |
| Related | [Background service architecture](../architecture/background-service.md), [Service protocol](../architecture/protocol.md), [Migration from FFI](../architecture/migration-from-ffi.md), [Product context](../brd/00-product-context.md) |

## Context

Sportcut ships two workspaces today:

- `core/`, a Rust workspace that owns the media pipeline, court calibration,
  vision and tracking, rally segmentation, score and serving derivation,
  highlight ranking, export rendering, the job registry, checkpoints, and the
  per-match artifact manifest.
- `app/`, a Flutter macOS client that owns the screens, playback, a versioned
  SQLite catalog (schema v5), and the app-owned copy of each imported
  recording.

The two workspaces meet at a frozen 17-call facade in `sportcut-api`, compiled
as `libsportcut_api.dylib` and consumed through `flutter_rust_bridge` 2.13.0.
`tools/build-engine-lib.sh` builds the dylib, `tools/embed-engine-lib.sh` puts
it in `Contents/Frameworks`, and the Dart wrapper in
`app/lib/src/bridge/sportcut_engine.dart` loads it with `RustLib.init`.

The product direction has changed. The backend must run as a separate
background service that is fully written in Rust, and the Flutter studio must
be a client only. The client must contain no Rust, no FFI to Rust, no
`dart:ffi` to Rust, no generated `flutter_rust_bridge` bindings, and no
`libsportcut_api.dylib`. The service may be packaged as a separately signed
executable or helper inside the app bundle; that is a separate process, not
Rust linked into the app. The client and service communicate over a documented
protocol.

The existing product behavior is a constraint, not a starting point to
redesign:

- the 17 facade calls keep their meaning;
- one heavy job runs at a time, and one job per match;
- progress is stage-labelled, monotonic within a stage, and observable;
- cancellation is cooperative and idempotent;
- checkpoints survive restart and a cancelled job never publishes a final
  artifact;
- the match artifact layout and every schema version stay stable;
- engine errors remain actionable and name the file and the reason.

macOS distribution adds three non-negotiable constraints: App Sandbox,
notarization, and a viable Mac App Store path if the product chooses it. The
current development runner disables the sandbox because the dylib lives outside
the app container and `dlopen` is blocked. That workaround cannot ship.

### The service-boundary question

Two boundaries are defensible.

**Option A — engine-only service.** Rust owns media, analysis, export, jobs,
and artifacts. Flutter keeps the SQLite catalog and recording custody. The
service is a compute backend; the client remains the system of record.

**Option B — backend-complete service.** Rust owns the engine, catalog,
recording custody, jobs, and export. Flutter is UI plus playback with an
in-memory cache. The service is the system of record.

The hard constraint is "backend should be an background service fully written
in rust" together with "the Flutter macOS studio is a client only." Under
Option A the catalog and recording custody remain business logic in Dart: the
catalog is durable product state, migrations are product behavior, and custody
is a security- and storage-relevant operation. Calling that "UI-local" would be
a rename, not a boundary. Option A also keeps two writers of match truth — the
service's match directories and the client's catalog — which is the current
split this decision is meant to remove.

Option B has a real cost: the v5 catalog must move, the recording store must
move, and both must migrate without data loss. That cost is bounded and can be
paid in phases, with the FFI path retained as a rollback until the protocol
path has parity.

## Decision

**Sportcut adopts Option B: a backend-complete Rust service.**

The Rust backend runs as a separate, app-supervised background service. The
service owns:

- the media engine (probe, proxy, analysis audio, frames, manifest,
  regeneration);
- court calibration, vision and player tracking, rally segmentation, score and
  serving derivation, highlight ranking, and export rendering;
- the job registry, admission control, job sessions, progress, cancellation,
  and checkpoints;
- the match catalog (SQLite), including workspaces, matches, rallies, score
  events, highlight clips, suggestion decisions, export settings, and the
  catalog copy of each calibration;
- recording custody: the durable copy of the recording the user picked;
- artifact storage for every match.

The Flutter macOS studio is a UI and playback client. It owns presentation,
navigation, the design-system implementation, transient view state, file
picking, the share sheet, and playback through `video_player`. It reads catalog
data through the protocol into an in-memory cache and holds no persistent
database and no recording custody. The one scoped exception is the sandbox
inbox handoff: if the security-scoped bookmark path cannot be proven, the client
may copy the picked bytes once into the service inbox, after which the service
owns, verifies, catalogs, and deletes them. That is an OS handoff, not a client
recording store, and the bookmark and inbox paths are mutually exclusive in a
shipped build.

The client and service communicate only over the **Sportcut Service Protocol
v1**, documented in [protocol.md](../architecture/protocol.md):

- **Primary transport:** a Unix domain socket (`AF_UNIX`, `SOCK_STREAM`) inside
  the app's shared container or application-support root, with a
  length-prefixed JSON frame, same-UID peer verification, and a per-launch
  token.
- **Fallback transport:** an XPC service (`NSXPCConnection`) carrying the same
  protocol messages, for the Mac App Store distribution path where Apple's
  sandboxed IPC mechanism is required or preferable.

The service is shipped as a separate signed executable inside the app bundle
(`Contents/Helpers/SportcutService` for the primary path, or
`Contents/XPCServices/SportcutService.xpc` for the fallback). It is a separate
process and a separate Mach-O image. It is never loaded into the Flutter
process, never packaged as a dylib, and never called through FFI.

The literal decision statement:

> The Rust backend is a separate background service process that owns the
> engine, catalog, recording custody, jobs, and export. The Flutter macOS
> studio is a client that talks to that service only over the documented
> Sportcut Service Protocol. No Rust code, FFI, `flutter_rust_bridge` bindings,
> `dart:ffi` bindings, or `libsportcut_api.dylib` is linked into or shipped
> inside the Flutter app executable.

## Consequences

### Positive

- **Process isolation.** An engine panic, a media-tool crash, or a runaway
  allocation no longer takes down the UI. The service can be restarted and the
  client can reconnect.
- **No ABI coupling.** The client no longer depends on a Rust ABI, a dylib
  search path, `dlopen`, or a generated binding layer. The contract is a
  versioned wire protocol that can be tested with a socket and a JSON fixture.
- **Sandbox and notarization become tractable.** A separately signed helper
  with the right entitlements is a supported macOS shape. The current
  unsandboxed development workaround disappears.
- **One system of record.** The service owns the catalog, recordings, artifacts,
  and job state. There is no dual-write and no reconciliation between a Dart
  database and Rust match directories.
- **The backend can be tested headlessly.** The service runs and is exercised
  with `cargo test` plus a socket client, with no Flutter, Xcode, or JDK.
- **Background jobs have a natural home.** A service process can outlive a
  window, keep one heavy job running, and publish progress even while the UI is
  rebuilding.
- **The client is honestly a client.** UI work cannot accidentally grow
  product persistence, because the client has no database and no custody code.

### Negative

- **Migration cost and risk are real.** The v5 catalog, its seven tables and
  five migrations, the recording store, and the playback path all move. A
  migration defect can lose a user's library. This is the largest risk in the
  decision and is mitigated by copy-first migration, parity checks, and a
  rollback window.
- **IPC is slower than an in-process call.** Small calls gain serialization and
  a context switch. Large payloads (player-track windows) need bounds and
  pagination.
- **Two executables to build, sign, and notarize.** Signing order, hardened
  runtime, helper entitlements, and universal binaries add release work.
- **Two DTO surfaces can drift.** The protocol models must be kept in step with
  the service DTOs. A schema and conformance test suite is required.
- **Debugging spans processes.** Logs, correlation IDs, and a health endpoint
  are not optional.
- **Lifecycle is more complex.** Launch, handshake, reconnection, crash backoff,
  idle exit, and orphan handling all need explicit rules.

### Neutral

- The 17 facade calls keep their semantics but change transport; the Dart
  wrapper is replaced by a protocol client.
- The job model, checkpoint files, manifest schema, artifact layout, and error
  messages are preserved.
- Playback remains file-based. The service returns a readable path inside the
  shared container; the client does not stream video over the protocol in v1.
- The catalog keeps the existing table shapes. The service adopts the v5
  database and bumps the schema to v6 with an additive ownership row, rather
  than redesigning the schema during a transport migration.
- The service is app-supervised in v1, not a login item or launchd agent.
- The protocol uses JSON in v1. MessagePack or another binary encoding is a
  later, additive decision.

## Alternatives considered and why rejected

| Alternative | Why rejected |
| --- | --- |
| **Option A — engine-only service** | Leaves the SQLite catalog, migrations, and recording custody in Dart. Those are durable product state and security-relevant operations, not UI-local state. It contradicts "backend fully written in Rust" and keeps two systems of record. It is acceptable only as an intermediate milestone, not as the target. |
| **Keep the FFI facade** | Directly violates the hard constraint: no Rust in the app, no FFI, no `dart:ffi`, no FRB, no dylib. Also preserves the unsandboxed `dlopen` workaround that blocks a shippable macOS build. |
| **Static-link Rust into the app** | Same violation in a different form. It also couples the client build to the Rust toolchain and makes the app binary language-mixed. |
| **Local TCP on `127.0.0.1`** | Adds a network listener and port allocation, needs the sandbox network-server entitlement, is reachable by any local process, and is harder to authenticate. A Unix socket in the app container is narrower and simpler. |
| **HTTP/REST over loopback** | Same network-surface and authentication problems as TCP, plus HTTP framing and server-library weight for no product benefit. The protocol is local RPC, not a public API. |
| **XPC as the only transport** | XPC is Apple-native and sandbox-friendly, but a pure-Rust service needs an Objective-C/Swift shim or the C `libxpc` API, and headless protocol tests become macOS-only. It is retained as the App Store fallback rather than the primary path. |
| **A launchd agent installed at login** | Better for a true always-on daemon, but it adds installer and lifecycle complexity, a persistent background process the user did not ask for, and update/version skew. The service is app-supervised in v1; a launchd agent is a later option. |
| **HTTP server plus a WebView UI** | Replaces the native Flutter studio and its design contract. Out of scope. |
| **MessagePack or Protobuf framing now** | Lower overhead, but not needed for the measured payloads, and it removes the ability to inspect and diff messages during migration. JSON is the v1 choice; the framing is versioned so a binary encoding can be added later. |
| **Keep the catalog in Dart and expose it to Rust over a callback** | Reintroduces FFI in the opposite direction and keeps two writers. Rejected for the same reason as Option A. |

## Constraints

- The service is fully written in Rust. macOS framework calls needed for
  sandbox file access or XPC are isolated OS glue, not product logic, and do
  not move Rust into the Flutter process.
- The workspace lint `unsafe_code = "deny"` keeps a narrow, documented
  exception for that OS-glue module only (`getpeereid`/`LOCAL_PEERCRED`,
  `flock`, parent-PID checks, bookmark resolution, `libxpc`). Safe wrapper crates
  (`nix`, `objc2`, `objc2-foundation`) are preferred and pinned; any remaining
  `unsafe` block lives in the named glue module, not in product logic. A lint
  test or CI check confines the allowance to that module.
- No Rust library is linked into the Flutter app. The service is a separate
  process and a separate executable.
- No `flutter_rust_bridge`, no generated FRB bindings, no `dart:ffi` to Rust,
  no `libsportcut_api.dylib`, and no `bridge` Cargo feature survive the
  migration.
- The client and service communicate only over the documented protocol. No
  side channel, no shared mutable memory, no direct database access from the
  client.
- One heavy job at a time and one job per match, enforced in the service.
- Progress, cancellation, checkpoints, artifacts, and error semantics are
  preserved.
- Catalog schema versions, manifest schema 3, checkpoint schema 1, calibration
  schema 1, tracks schema 1, and rally-suggestions schema 1 remain readable.
- App Sandbox, hardened runtime, notarization, and the App Store fallback are
  release constraints, not follow-ups.
- The product remains offline. The protocol is local-only and adds no network
  dependency.
- The migration is phased. A big-bang rewrite is not permitted.

## Compliance with the no-Rust-in-app rule

This decision satisfies the rule in four independent ways:

1. **Build graph.** `app/pubspec.yaml` has no `flutter_rust_bridge` dependency;
   `app/` has no `dart:ffi` import; no generated binding directory exists.
   `core/adapters/api` is an `rlib` consumed by the service binary; in the XPC
   variant a separate `core/xpc-bridge` `staticlib` depends on it and is linked
   only into the separate XPC executable. Nothing is a `cdylib` loaded by
   Flutter.
2. **Bundle contents.** The built `Sportcut.app` contains no
   `Contents/Frameworks/libsportcut_api.dylib`. It contains a separate signed
   helper at `Contents/Helpers/SportcutService` (or an XPC service in the
   fallback layout). `otool -L` on the Flutter executable lists no Sportcut
   Rust library.
3. **Process boundary.** The helper is launched with `Process.start` or XPC. It
   has its own PID, its own address space, and its own Mach-O image. It is
   never `dlopen`ed.
4. **Continuous enforcement.** CI runs
   `tools/check-no-rust-in-app.sh`, which greps the client tree, inspects the
   built bundle, checks linked libraries, and fails on any FFI or dylib
   residue. The exact checks are listed in
   [background-service.md](../architecture/background-service.md#15-no-rust-in-app-enforcement).

## Open questions

| ID | Question | Why it matters | Owner |
| --- | --- | --- | --- |
| Q-1 | Is the primary distribution Developer ID plus notarization, or the Mac App Store? | It decides whether the Unix-socket helper or the XPC service is the primary packaging and which entitlements are mandatory. The ADR keeps both paths; release sequencing needs one. | Product owner |
| Q-2 | Can the sandboxed helper resolve a security-scoped bookmark from the app's open panel in Rust OS glue, given the bookmark entitlement on both targets, or must the app hand the file into the service inbox? | This is the riskiest sandbox detail for recording custody. A signed sandbox spike must prove resolution (create, pass, resolve, read, SHA-256, source unchanged) before the bookmark path ships. If it fails, the inbox handoff becomes primary and the bookmark entitlements and code are removed. The fallback changes who performs the byte copy but not who owns the result. | Engineering lead |
| Q-3 | Should the service persist its job registry across a service crash, or is checkpoint resume plus a "re-run" error sufficient? | It affects recovery UX after a helper crash. Checkpoints already prevent lost work; handle resumption is a separate promise. | Engineering lead |
| Q-4 | Which SQLite crate and linkage model ships: `rusqlite` with a bundled SQLite, or the system library? | It affects the license register, binary size, and macOS deployment target. | Engineering lead / Legal/licensing |
| Q-5 | How is a shippable FFmpeg delivered inside the signed helper and its sandbox? | The current GPL development build is not shippable (R-2), and the helper now launches the media tool itself. | Legal/licensing |
| Q-6 | Does the client ever stream playback through the service, or always read a file path? | `video_player` needs a file or URL. The v1 answer is a file path; a future sandbox layout could break that assumption. | Engineering lead |
| Q-7 | Is a protocol schema codegen step worth adding for the Dart models, or are hand-written models plus golden tests enough? | It trades a build step for drift protection. The migration can start hand-written and reconsider at Phase 2. | Engineering lead |
| Q-8 | What is the acceptable migration window for existing users, and is a one-time data-location move acceptable without an explicit consent screen? | Moving recordings and catalog changes where user data lives. Privacy review may require disclosure. | Product owner / Security/privacy |
| Q-9 | For the XPC fallback, which process graph and container mechanism ships: Rust statically linked into the XPC target with an App Group, or an XPC relay to a third helper process with inherited container access? | The two variants differ in process count, entitlements, and the state-root path; the endpoint length limit applies to the relay. A sandbox smoke test must prove one before the fallback is claimed viable. | Engineering lead |

## Approval

| Role | Name | Decision | Date |
| --- | --- | --- | --- |
| Engineering lead |  | Approve / revise |  |
| Product owner |  | Approve / revise |  |
| Security/privacy |  | Approve / revise |  |
| Legal/licensing |  | Approve / revise |  |
| QA lead |  | Approve / revise |  |
| Design lead |  | Approve / revise |  |

---

**Change control.** A change to the service boundary, the transport, the
catalog ownership, or the no-Rust-in-app rule requires a superseding ADR, an
update to the product BRD, and a re-run of the migration and packaging gates.
