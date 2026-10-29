# Sportcut background service architecture

| Field | Value |
| --- | --- |
| Status | Proposed target architecture |
| Date | 2026-10-29 |
| Decision | [ADR-0001](../adr/0001-rust-background-service.md) — backend-complete Rust service |
| Engine layering | [Engine layering](layering.md) — Clean Architecture layers and crate rules |
| Protocol | [Sportcut Service Protocol v1](protocol.md) |
| Migration | [Migration from FFI](migration-from-ffi.md) |
| Requirements | [Product context](../brd/00-product-context.md) |

## 1. Scope and related documents

This document describes the target runtime architecture of the Sportcut
background service after ADR-0001: the process boundary, the wire transport,
lifecycle and supervision, data ownership, security, packaging, and the
enforcement that keeps Rust out of the Flutter app. It does not restate the
engine's internal design or the exact wire shapes.

Three documents hold the detail this one relies on:

- [Engine layering](layering.md) defines the Clean Architecture layers, the
  allowed crate dependencies, the ports, and the single declared adapter
  exception. Its layer model is decided by
  [ADR-0002](../adr/0002-clean-architecture-engine.md). This document names the
  layer and directory of every engine component it touches but does not restate
  the dependency rules.
- [protocol.md](protocol.md) is the normative wire contract: framing, handshake,
  methods, DTOs, error codes, progress, and limits. §6 summarises it and defers
  to it for exact shapes.
- [ADR-0001](../adr/0001-rust-background-service.md) records why the backend is
  a separate process and why the service owns the catalog, recording custody,
  jobs, and export.

Where the documents overlap, `protocol.md` wins on wire details and
`layering.md` wins on crate dependencies. This document does not change product
behaviour: the 17 facade calls, the one-heavy-job rule, progress, cancellation,
checkpoints, artifacts, and error semantics are preserved; only their transport
and ownership change.

## 2. Goals and non-goals

### Goals

- Run the whole backend as a separate process written in Rust: engine, catalog,
  recording custody, jobs, and export.
- Make the Flutter macOS studio a client only, with no Rust, no FFI, no
  `dart:ffi`, no generated `flutter_rust_bridge` bindings, and no
  `libsportcut_api.dylib`.
- Keep the product offline and local-only. The protocol is the only client–
  service channel, and it carries no network traffic.
- Preserve observable behavior: facade calls, one heavy job at a time, one job
  per match, stage-labelled monotonic progress, cooperative cancellation,
  checkpoint resume, atomic artifacts, and actionable errors.
- Ship under App Sandbox, hardened runtime, and notarization, with a viable
  Mac App Store fallback.
- Land in phases with rollback, not as a big-bang rewrite.

### Non-goals

- A network service, remote API, cloud sync, or multi-user server.
- A login item or always-on launchd daemon in v1.
- Streaming video over the protocol in v1. Playback reads a file path.
- Redesigning the catalog schema or the match artifact layout during the
  transport migration.
- Moving UI rendering, the design system, playback, or the share sheet into the
  service.

## 3. Component diagram

```text
┌───────────────────────────── Sportcut.app (Flutter, macOS) ─────────────────────────────┐
│                                                                                         │
│  Presentation                 Riverpod state                 Playback                   │
│  screens, routes,  ────────►  view models,        ────────►  video_player               │
│  design system                in-memory cache                 (reads a service path)    │
│       │                            │                                  ▲                 │
│       │                            │                                  │                 │
│       ▼                            ▼                                  │                 │
│  ┌──────────────────────────────────────────────────────┐              │                 │
│  │ ProtocolClient (dart:io Socket, typed models)        │──────────────┘                 │
│  │ request/response correlation, notifications, timeouts │                                │
│  └──────────────────────────────────────────────────────┘                                │
│       │                                                                                 │
└───────┼─────────────────────────────────────────────────────────────────────────────────┘
        │  AF_UNIX SOCK_STREAM, 4-byte big-endian length + UTF-8 JSON
        │  (fallback: NSXPCConnection carrying the same messages)
┌───────▼──────────────────────── SportcutService (separate Rust process) ────────────────┐
│                                                                                         │
│  LAYER 3 — core/adapters/service          interface adapter                             │
│  ┌──────────────────┐  ┌───────────────────────┐  ┌──────────────────────────────────┐  │
│  │ Transport        │─►│ RPC dispatcher        │─►│ Method handlers                  │  │
│  │ UDS listener     │  │ framing, auth,        │  │ service.*   engine.*             │  │
│  │ (or XPC shim)    │  │ version, idempotency  │  │ library.*   job.*                │  │
│  └──────────────────┘  └───────────────────────┘  └──────────────┬───────────────────┘  │
│                                              service-owned stores │                      │
│                                              Catalog (SQLite v6)  │                      │
│                                              RecordingStore       │                      │
│                                                                   │                      │
│                               declared exception (§3.1) ─────────┤                      │
│                                                                   ▼                      │
│  LAYER 3 — core/adapters/api    sportcut-api: the use cases and their DTOs; an          │
│                                 ordinary library parked here pending a move inward      │
│                                     │                                                   │
│                                     ▼                                                   │
│  LAYER 1 — core/use-cases/      sportcut-media   sportcut-vision   sportcut-export      │
│                                 sportcut-jobs    (sportcut-eval is CLI-only)            │
│                                     │                                                   │
│  LAYER 0 — core/entities/       sportcut-common  sportcut-court   sportcut-rally        │
│                                 sportcut-score   sportcut-highlight                     │
│                                     │  ports: ArtifactStore (media),                    │
│                                     │         CheckpointStore (jobs)                    │
│  LAYER 2 — core/gateways/       sportcut-storage  implements both ports over the        │
│                                 filesystem; sportcut-protocol encodes the wire          │
│                                 contract as data                                        │
│                                     │                                                   │
│  Artifact store  matches/<id>/manifest.json, checkpoints.json,                          │
│                  proxy/ audio/ frames/ calibration/ tracks/ export/                     │
│  Media toolchain: ffmpeg / ffprobe as child processes (argument arrays, no shell)       │
└─────────────────────────────────────────────────────────────────────────────────────────┘

core/drivers/cli (LAYER 4) is a separate composition root for headless work. It is not
part of the service process and is never shipped inside Sportcut.app.
```

The service is a separate Mach-O executable with its own PID and address space.
The Flutter app never loads it; it launches it and talks to it. `otool -L` on
the Flutter executable shows no Sportcut Rust library.

Source dependencies point inward: adapters → use cases → entities. Calls run
outward through the ports: a use case asks `ArtifactStore` or `CheckpointStore`
for data, and `sportcut-storage` answers. `sportcut-protocol` is pure data, so
both the service adapter and the Flutter client's protocol models can be
checked against the same contract.

### 3.1 Engine layers and the declared exception

| Layer | Directory | Crates | Role |
| --- | --- | --- | --- |
| 0 | `core/entities/` | `sportcut-common`, `sportcut-court`, `sportcut-rally`, `sportcut-score`, `sportcut-highlight` | Rules over data; no filesystem, process, environment, or network access |
| 1 | `core/use-cases/` | `sportcut-media`, `sportcut-vision`, `sportcut-export`, `sportcut-jobs`, `sportcut-eval` | Application orchestration; each declares the ports it needs. `sportcut-eval` is driven by `sportcut-cli` |
| 2 | `core/gateways/` | `sportcut-storage`, `sportcut-protocol` | Storage implements the ports over the filesystem; protocol encodes the wire contract as data |
| 3 | `core/adapters/` | `sportcut-service`, `sportcut-api` | JSON-RPC translation. `sportcut-api` holds the use cases and is parked here pending a move to `core/use-cases/` |
| 4 | `core/drivers/` | `sportcut-cli` | Headless composition root; not part of the service process |

The two ports the service relies on are declared inward and implemented in the
storage gateway:

| Port | Declared in | Implemented by |
| --- | --- | --- |
| `ArtifactStore` | `sportcut-media` (`core/use-cases/media`), module `pipeline` | `sportcut-storage` (`core/gateways/storage`), `MatchDirectory` |
| `CheckpointStore` | `sportcut-jobs` (`core/use-cases/jobs`), module `checkpoint` | `sportcut-storage` (`core/gateways/storage`), `CheckpointStore` |

`core/adapters/service` depends on `core/adapters/api`. This is the one
declared adapter-to-adapter edge in the workspace. The engine's use cases live
in `sportcut-api`, which is an ordinary library — no FFI, no generated code, no
client toolchain — but which is parked in `adapters/`, so the check sees two
adapters. The edge is recorded in `layering.md` and in
`tools/check-layering.sh` with the same removal condition: moving the crate to
`core/use-cases/` makes the edge adapter → use case, which the rule allows, and
deletes the exception. The Flutter client no longer links Rust at all, so no
client contract depends on where this crate sits.

## 4. Service boundary

The boundary rule is simple: **durable state and product operations belong to
the service; ephemeral view state belongs to the client.**

| Concern | Service (Rust) | Flutter client |
| --- | --- | --- |
| Media probe, proxy, analysis audio, frames, manifest, regeneration | Owns | Displays progress and artifacts |
| Court calibration artifact and geometry | Owns | Draws handles and outline from returned geometry |
| Vision and player tracking | Owns | Displays tracks and review evidence |
| Rally segmentation | Owns | Accepts, adjusts, dismisses proposals through catalog calls |
| Score and serving derivation | Owns | Sends confirmed winners; renders score |
| Highlight ranking | Owns | Sends rally signals; renders ranking |
| Export render | Owns | Collects settings; sends edit decision list; shows progress |
| Job registry, admission, sessions, checkpoints | Owns | Watches status and progress; sends cancel |
| SQLite catalog and migrations | Owns | In-memory cache of reads; no local database |
| Recording custody and deletion | Owns | Picks the file; plays the service path |
| Workspace, match, rally, score, clip, settings CRUD | Owns | Calls CRUD; keeps cache |
| Screens, routing, design tokens, accessibility | Does not own | Owns |
| Transient selection, drag, hover, form drafts | Does not own | Owns |
| Playback | Serves the path | Owns `video_player` |
| File picker and security-scoped access | Accepts a path or bookmark | Owns the open panel |
| Overlay and title rendering for export | Accepts images as inputs | Renders images |
| Share sheet | Returns the output path | Owns `share_plus` |

Judgment rule applied to ambiguous cases:

- If losing the value on a crash would change the user's library, it belongs to
  the service.
- If losing the value on a window rebuild is harmless, it belongs to the
  client.
- If it is a user-owned file outside the service store, the service may read it
  only for the duration of an explicit import; it never modifies it.

The former client-owned pieces are therefore explicitly in scope for the
service:

- `app/lib/src/features/library/data/match_catalog.dart` (schema v5 and its
  migrations);
- `app/lib/src/features/library/data/recording_store.dart` (custody copy);
- `app/lib/src/features/library/data/match_paths.dart` (artifact and recording
  roots);
- the parts of `match_repository.dart` that write the catalog or the recording
  store;
- `editing_store.dart` and its typed CRUD over rallies, score events, clips,
  suggestion decisions, and export settings.

Presentation code, providers, playback, and the design system stay in the
client.

## 5. Process, lifecycle, and supervision

### 5.1 Executable and launch

- Primary path: `Sportcut.app/Contents/Helpers/SportcutService`, a universal
  Mach-O signed with the same Team ID as the app.
- Fallback path: `Sportcut.app/Contents/XPCServices/SportcutService.xpc`.
- The app launches the helper on first use (startup or the first catalog/engine
  call) with explicit arguments, not a shell:
  - `--state-root <path>` — the shared container or application-support root;
  - `--endpoint <path>` — the Unix socket path. The default is
    `<container>/Data/run/s.sock` under the App Sandbox and
    `<state-root>/run/service.sock` only for a non-sandboxed build when it fits.
    `sun_path` is 104 bytes including the terminator; the service refuses a
    path over 103 bytes with an actionable `endpoint_too_long` error and never
    truncates. See [protocol.md §1.1](protocol.md#31-primary-transport);
  - `--parent-pid <pid>` — the app process to supervise;
  - `--log-level <error|warn|info|debug>`;
  - `--ffmpeg <path>` and `--ffprobe <path>` — explicit media tool binaries.
    When a flag is absent the media pipeline honors `SPORTCUT_FFMPEG` /
    `SPORTCUT_FFPROBE` when set, then falls back to `PATH` discovery. A packaged
    launch always passes the explicit flags, so the environment and `PATH`
    fallbacks are development shapes only;
  - `--tflite-library <path>` and `--person-model <path>` — explicit inference
    assets. When a flag is absent the service resolves the file next to its
    executable in the app bundle (`Contents/Frameworks/libtensorflowlite_c.dylib`
    and `Contents/Resources/model.tflite`), then the `SPORTCUT_TFLITE_LIBRARY`
    and `SPORTCUT_PERSON_MODEL` environment variables.
- The service, not the client and not the ambient shell, owns media tool
  discovery and inference asset resolution. It resolves the inference assets
  once at startup, before any worker thread starts, and publishes every explicit
  tool path and every resolved asset as `SPORTCUT_FFMPEG`, `SPORTCUT_FFPROBE`,
  `SPORTCUT_TFLITE_LIBRARY`, and `SPORTCUT_PERSON_MODEL`. The media use case
  (`sportcut-media`, `core/use-cases/media`) and the player-tracking job hosted
  by the `sportcut-api` adapter (`core/adapters/api`) therefore read the same
  service-owned paths. A client-supplied `runtimePath` or `modelPath` on
  `engine.tracking.start` is rejected with `invalid_params`; the service never
  lets a caller override its configured runtime or model.
- `ffmpeg` and `ffprobe` remain required at runtime for probe, proxy, audio,
  frames, and export. Inference assets are optional: without them the service
  starts and serves everything except player tracking, and `service.health`
  reports why.
- Environment is minimal and explicit: a `SPORTCUT_SERVICE_TOKEN` value is
  generated by the app and written to `<state-root>/run/token` with mode `0600`;
  the service also accepts it from the launch environment. No secrets are
  passed on a command line that other users can read from `ps`; the token file
  is the source of truth.
- The helper never opens the user's original recording except during an import
  it was explicitly asked to perform, and then only read-only.

### 5.2 Single instance and endpoint ownership

- The service takes an exclusive `flock` on `<state-root>/run/service.lock`.
- If the lock is held, the new process prints the existing endpoint and exits
  `0`. The client connects to the existing instance instead of starting a
  second one.
- On startup, a stale socket file with no live owner is removed; a live socket
  is never unlinked.
- The socket directory is `0700`, the socket is `0600`, and the token file is
  `0600`.
- The app never starts more than one helper. A failed launch is retried with
  exponential backoff: 1 s, 2 s, 4 s, then an actionable error in the UI.

### 5.3 Handshake and readiness

- The client connects, sends `service.hello`, and receives the service
  version, protocol version, catalog schema version, instance ID, state root,
  capability list, and limits.
- Readiness means the catalog is open and migrated, the state root is writable,
  and the media toolchain has been probed. The service may accept connections
  before the media toolchain is ready and report `toolchain_unavailable` on
  media methods; `service.health` reports the detail.
- The client never issues engine calls before a successful handshake.
- Handshake timeout is 5 s; on failure the client kills and relaunches the
  helper.

### 5.4 Steady state

- The service handles multiple connections, but only from the same UID and with
  a valid token.
- Only one heavy job runs at a time and only one job per match, enforced by the
  existing registry semantics. The single-heavy-job rule is a use-case rule in
  `sportcut-jobs` (`core/use-cases/jobs`).
- Lightweight calls (catalog reads, status, geometry on a small segment) are
  served concurrently with a heavy job.
- The service sends `job.progress` notifications at most 20 times per second
  per job, coalescing faster engine events. A status poll always returns the
  latest value, so a dropped notification is not a correctness problem.

### 5.5 Idle exit

- The service exits after 120 s with no open connections and no running jobs.
  The complete precedence rules are in §5.9.
- It does not exit while a job is running, even with no client connected.
- It writes no shutdown marker that could hide an abnormal exit; `service.log`
  records the reason.

### 5.6 App termination

- On a normal app quit, the client sends `service.shutdown` with
  `cancelRunningJobs: true`.
- The service requests cancellation, waits up to 10 s for cooperative stop,
  releases locks and sockets, flushes logs, and exits.
- A cancelled job leaves checkpoints and non-final artifacts; it never
  publishes a final artifact. Checkpoints are read and written through
  `CheckpointStore`, implemented by `sportcut-storage`
  (`core/gateways/storage`).
- If the app crashes or is force-quit, the parent-gone rule in §5.9 applies:
  with no job running it exits after 30 s; with a job running it requests
  cancellation immediately and exits after the job reaches a terminal state
  (or after 10 s, whichever is later). Checkpoints make the next run
  resumable.

### 5.7 Crash and restart

- A helper crash is contained: the UI stays alive and shows a service-error
  state.
- The client relaunches with backoff and, on reconnect, reads catalog state and
  match manifests. Job handles from the dead process are gone; the client
  receives `job_not_found` with an actionable message and can restart the
  operation from checkpointed state.
- The service never leaves a final artifact behind for an interrupted job: the
  manifest flip happens only after the output is complete.
- The service writes a crash breadcrumb to `<state-root>/logs/service.log`
  before aborting on a caught panic path. A panic is a bug, not a control flow.
- **Startup sweep.** After the catalog opens and before readiness, the service
  scans `recordings/`, `render-inputs/`, and `inbox/` for crash orphans. It
  removes a `recordings/<matchId>/` directory or `.part` file only when no
  catalog row references the match and no import or relocate job is active. It
  removes unreferenced `render-inputs/<uuid>/` directories and stale
  `inbox/*.part` files using the rules in §8.3. The sweep is logged and has a
  failure-injection test that kills the service mid-copy and asserts that the
  next start removes the orphan. The sweep belongs to the service adapter
  (`core/adapters/service`); artifact files under `matches/` are written by
  `sportcut-storage` (`core/gateways/storage`).

### 5.8 Supervision boundary

- v1 is app-supervised, not a system daemon. The service does not install
  launchd jobs and does not start at login.
- The service monitors `--parent-pid`; if the parent is gone and no job is
  running, it exits after the idle grace period. A future ADR may add a
  launchd agent if the product needs work to continue after the app quits.

### 5.9 Lifecycle state machine

One state machine owns every timing rule. The timers are:

| Timer | Value | Applies to |
| --- | --- | --- |
| Connection idle timeout | 300 s of no frames on a connection | That connection only; it is closed and the client reconnects |
| App-crash / parent-gone grace | 30 s after `--parent-pid` is gone or re-parented | The service process |
| Idle-exit threshold | 120 s with zero client connections and zero running jobs | The service process |
| Shutdown wait | 10 s for cooperative stop | `service.shutdown` |

Precedence, highest first:

1. **A running job blocks exit.** The service never exits while any heavy job
   is running, including `library.match.import`,
   `library.recording.relocate`, and `library.catalog.adoptLegacy`.
2. **`service.shutdown` wins over every timer.** It requests cancellation,
   waits up to 10 s, flushes, and exits.
3. **Parent gone.** When `--parent-pid` is gone:
   - with no job running, exit after the 30 s grace;
   - with a job running, request cancellation, then exit after the job reaches a
     terminal state (or after 10 s, whichever is later).
4. **Connection idle timeout.** It closes an idle connection but does not exit
   the service while another client connection is open. When the last
   connection closes, the idle-exit clock starts.
5. **Idle exit.** After 120 s with no connections and no job, exit.

Consequences that must be stated rather than inferred:

- An always-connected but idle client is disconnected after 300 s, then the
  service exits 120 s later, so the maximum observed lifetime with no work is
  about 420 s. The 120 s figure alone is not the whole story.
- A client that reconnects before the 120 s idle threshold cancels the pending
  exit.
- The service logs which rule fired, its timer value, and the elapsed time.

## 6. Protocol summary

The wire contract is encoded as data by `sportcut-protocol`
(`core/gateways/protocol`) and served by `sportcut-service`
(`core/adapters/service`). The full contract is in [protocol.md](protocol.md).
In brief:

- **Transport:** Unix domain socket primary; XPC fallback.
- **Framing:** 4-byte big-endian unsigned length, then a UTF-8 JSON object.
  Maximum frame 16 MiB. No newline framing.
- **Message model:** JSON-RPC 2.0 subset. Requests carry `id`, `method`, and
  `params`; responses carry `id` and `result` or `error`; notifications carry
  no `id`.
- **Handshake:** `service.hello` negotiates protocol major/minor, capabilities,
  catalog schema, and limits.
- **Methods:** `service.*`, the 17 `engine.*` facade equivalents, and
  `library.*` catalog and custody CRUD.
- **Events:** `job.progress`, `job.state`, `catalog.changed`,
  `service.shutdown`.
- **Errors:** a stable code, a diagnostic `message`, and a `data` object with
  `kind`, `retryable`, optional `stage` and `jobId`, and a user-safe
  `userMessage`.
- **Progress and cancellation:** start methods return a job handle immediately;
  cancellation is cooperative and idempotent; terminal states are `completed`,
  `cancelled`, and `failed`.

## 7. Data ownership

### 7.1 State root

The service resolves one root and reports it in the handshake:

| Context | Root |
| --- | --- |
| App Sandbox, Developer ID helper | `~/Library/Containers/com.sportcut.sportcut/Data/Library/Application Support/Sportcut` |
| App Store XPC with an App Group | `~/Library/Group Containers/group.com.sportcut.shared/Sportcut` |
| Developer ID, non-sandboxed support build | `~/Library/Application Support/Sportcut` |

Layout:

```text
<state-root>/
  catalog.sqlite            # service-owned SQLite, schema v6
  catalog.sqlite-wal        # WAL, if enabled
  catalog.sqlite-shm
  backups/                  # pre-migration copies and adoption checkpoints
  recordings/<matchId>/<sanitized-name>
  matches/<matchId>/        # unchanged artifact layout
    manifest.json
    checkpoints.json
    proxy/ audio/ frames/ calibration/ tracks/ export/
  render-inputs/<uuid>/     # app-rendered overlay and title images
  inbox/                    # sandbox handoff, see 8.3
  run/service.lock
  run/token
  logs/service.log
```

The Unix socket is **not** under `<state-root>`. In the sandbox it is
`<container>/Data/run/s.sock`, because the state-root path is too long for
`sockaddr_un.sun_path`; the lock, token, logs, and data can stay under the
state root because they are ordinary file paths with no 104-byte limit. The
handshake reports the endpoint so the client never guesses it.

### 7.2 Catalog

The service owns `catalog.sqlite`. The schema is the existing v5 schema plus an
additive v6 migration:

- tables kept exactly: `matches`, `rallies`, `score_events`,
  `highlight_clips`, `export_settings`, `rally_suggestion_decisions`,
  `workspaces`;
- indexes kept exactly;
- v6 adds `catalog_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` with
  `owner=service`, `adopted_from=v5|fresh`, and a random `catalog_id`;
- all v5 rows, columns, and null semantics are preserved;
- the service implements fresh v6 creation and the v5 → v6 adoption step. It
  does not renumber or restructure the user's data;
- every service connection opens with `PRAGMA foreign_keys = ON`,
  `journal_mode = WAL`, and a `busy_timeout`. The v5 schema relies on
  `ON DELETE CASCADE` and `ON DELETE SET NULL`, and SQLite defaults
  `foreign_keys` to off, so leaving it off would silently skip the cascade.
  Migration tests assert cascade delete and clip detach-on-rally-delete with
  the pragma on.

The catalog is the source of truth for library data. The client's cache is
ephemeral and is invalidated by `catalog.changed` notifications and by
refetching after mutations.

The catalog is service-owned state, not part of the engine layer model. The
service adapter (`core/adapters/service`) exposes it through the `library.*`
methods.

### 7.3 Recording store

- The service copies a picked recording into
  `<state-root>/recordings/<matchId>/<sanitized-name>`.
- The copy is streamed, written to a `.part` file, flushed, and renamed only
  when complete.
- Cancellation or failure removes the whole match recording directory; a
  partial copy can never be mistaken for a recording.
- A crash mid-copy can leave `recordings/<matchId>/*.part` and a reserved match
  id with no catalog row. The startup sweep in §5.7 removes such a directory
  only after confirming that no catalog row references the match and no import
  or relocate job owns it.
- The source file is opened read-only and is never written, moved, renamed, or
  deleted.
- The catalog records the service-owned path, the original source path, and the
  copied byte count.
- Deletion removes the recording only when the caller asks for it, and the
  original user file is never touched.

### 7.4 Artifacts

- The artifact layout owned by the storage gateway (`sportcut-storage`,
  `core/gateways/storage`) is unchanged: `manifest.json`, `checkpoints.json`,
  and `proxy/`, `audio/`, `frames/`, `calibration/`, `tracks/`, `export/`
  inside `matches/<matchId>/`.
- Manifest schema 3, checkpoint schema 1, calibration schema 1, tracks schema 1,
  and rally-suggestions schema 1 remain readable and writable. The manifest
  model is an entity in `sportcut-common` (`core/entities/common`); the gateway
  persists it.
- Artifact writes stay atomic: temp file plus rename, or a final-state flip
  after the output is complete.

### 7.5 Playback

- The service returns `library.recording.path` for a match. The path is inside
  the shared container and readable by the app under both packaging models.
- The client passes that path to `video_player`. No video bytes cross the
  protocol in v1.
- If a future sandbox layout makes the path unreadable, the fallback is a
  service-owned local HTTP stream or an XPC file handle; that requires a new
  ADR and is not part of v1.

## 8. Security

### 8.1 Threat model

The service is a local, same-user backend. It is not a privilege boundary
against a hostile process running as the same user; no local IPC can be. It is
a boundary against other users, other apps, accidental network exposure, and
the Flutter process consuming Rust unsafely. The design still applies
defense-in-depth.

### 8.2 Transport authentication

- Same-UID peer verification using `getpeereid` (or `LOCAL_PEERCRED`) on every
  accepted Unix socket connection. A peer with a different UID is disconnected
  before any request is read. The call lives in the service's OS-glue module
  (`core/adapters/service/src/os_glue.rs`).
- Socket directory `0700`, socket `0600`, token file `0600`.
- Per-launch random token, sent in the `service.hello` params and checked
  before any other method. A wrong token returns `unauthorized` and closes the
  connection.
- The token is not logged and is redacted from diagnostics.
- No TCP listener. The sandbox entitlement
  `com.apple.security.network.server` is removed from the app.

### 8.3 Sandbox file handoff

There are two handoff shapes. At most one is enabled in a shipped build; the
other is removed, not left as a hidden fallback. Which one ships is decided by
the sandbox spike below, not by preference.

**Primary candidate: security-scoped bookmark.**

- The app's `NSOpenPanel` returns a security-scoped URL. The app creates a
  bookmark with security scope and passes
  `{ "kind": "bookmark", "value": "<base64>" }` to
  `library.match.import` or `library.recording.relocate`.
- The service resolves the bookmark, calls `startAccessingSecurityScopedResource`,
  copies the file, and stops access. The bookmark is never persisted after the
  operation.
- Entitlements required for this path:
  - App: `com.apple.security.files.user-selected.read-only` and
    `com.apple.security.files.bookmarks.app-scope` (the app creates an
    app-scoped bookmark). If document-scoped bookmarks are chosen instead, use
    `com.apple.security.files.bookmarks.document-scope`.
  - Helper: `com.apple.security.files.user-selected.read-only`,
    `com.apple.security.inherit`, and the same bookmark entitlement
    (`app-scope` or `document-scope`) so it can resolve and read the bookmark
    the app created. The bookmark entitlement is not implicit in `inherit`.
- The resolution is implemented as isolated OS glue (objc2/objc2-foundation or
  the C CoreFoundation calls) behind a safe wrapper in the service's OS-glue
  module (`core/adapters/service`); it contains no product logic.
- **Proof gate.** This path is unproven. A sandbox spike on a signed,
  notarizable build must: create the bookmark in the app, pass the bytes to the
  helper over the real transport, resolve the bookmark in the helper, open and
  read the file, verify SHA-256 against the source, and leave the source
  unchanged. The result is recorded in the release evidence. Until the spike
  passes, Q-2 in ADR-0001 stays open and this path is not claimed as working.
  If it fails, the inbox path below becomes primary and the bookmark
  entitlements and code are removed.

**Inbox handoff (first-class if the bookmark path fails).**

- The app writes exactly one file per import:
  `<state-root>/inbox/<uuid>.part`, mode `0600`, then fsyncs and renames it to
  `<state-root>/inbox/<uuid>.ready`. A `.ready` file is never partial. The app
  computes SHA-256 while writing and sends
  `library.match.adopt` with `{ "path": ".../<uuid>.ready", "sha256": "...", "sizeBytes": 123 }`.
- The service re-hashes the `.ready` file before moving it into
  `recordings/<matchId>/`; a mismatch is `invalid_input` and the file is
  removed. The service validates, probes, moves or copies atomically, and owns
  cataloging, deletion, and cleanup. The app performs only the OS byte handoff;
  it holds no recording after the call returns.
- The **source is immutable**: the app reads the picked file, never writes,
  moves, renames, or deletes it. The inbox file is a byte copy, not the
  original.
- **Crash recovery and cleanup.** The service removes the `.ready` file after
  the recording is committed. On startup the service sweep (§5.7) deletes
  `.part` files older than 24 hours and `.ready` files with no matching active
  adopt job; a `.ready` with a matching retry is adopted idempotently by its
  `clientRequestId`. The app removes its own `.part` file on cancel.
- The bytes cross process boundaries in this shape, which is why it is scoped
  narrowly: one file, one handoff, verified digest, service-owned result. It is
  not a client recording copy and it is deleted as soon as custody succeeds.

The service canonicalizes every caller-supplied path and rejects anything
outside the state root or an allocated directory, except the explicitly
approved source bookmark and render-input directory.

### 8.4 Path and process safety

- No shell invocation. `ffmpeg` and `ffprobe` run with argument arrays and a
  sanitized environment.
- No path traversal: relative paths are resolved against the match directory
  and checked with `strip_prefix`.
- Export inputs (overlay and title images) are read from a per-job
  `render-inputs/<uuid>` directory and deleted after the job reaches a terminal
  state.
- Filenames derived from user input are sanitized with the existing recording
  store rules: no separators, no `..`, bounded length, safe extension.
- Inference assets are service-owned. The service resolves its own TFLite
  runtime and person model at startup and publishes the paths to the engine;
  `engine.tracking.start` rejects a caller-supplied `runtimePath` or `modelPath`.
- No secrets in source or logs. Local file paths may appear in local logs but
  not in any remote channel, because there is none.

### 8.5 Data protection

- The catalog, recordings, and artifacts live in the app container or the
  user's application-support directory, protected by normal macOS file
  permissions and, when enabled, FileVault.
- The service does not add encryption at rest in v1; the product promise is
  local-only, not encrypted-at-rest. This can be revisited without a protocol
  change.

## 9. Sandbox, packaging, signing, and notarization

### 9.1 Primary: Developer ID, sandboxed, Unix-socket helper

This is the default shippable shape.

- App target: `com.apple.security.app-sandbox` = true,
  `com.apple.security.files.user-selected.read-only` = true, and, when the
  bookmark path is enabled,
  `com.apple.security.files.bookmarks.app-scope` = true, with no network
  entitlement.
- Helper: `Contents/Helpers/SportcutService`, signed with the same Team ID,
  hardened runtime enabled, with `com.apple.security.app-sandbox` = true and
  `com.apple.security.inherit` = true so it runs inside the app's sandbox and
  container. When the bookmark path is enabled it also carries
  `com.apple.security.files.user-selected.read-only` and the same bookmark
  entitlement (`app-scope` or `document-scope`); the bookmark entitlement is
  required for resolution and is not implied by `inherit`. It has no network
  entitlement and no temporary-exception entitlement.
- The helper is built as a universal binary (`aarch64-apple-darwin` and
  `x86_64-apple-darwin`) and stripped.
- Sign order is inside-out: media tools, helper, app frameworks, app. Then
  notarize the whole bundle, staple the ticket, and verify with
  `spctl --assess` and `codesign --verify --deep --strict`.
- The app and helper declare the same `CFBundleShortVersionString` and a
  build-specific service version. Version skew inside one bundle is a release
  error.

### 9.2 Fallback: Mac App Store, XPC service

If the product chooses the Mac App Store (Q-1), the transport switches to XPC.
The process graph and container access must be fixed, not left implicit.

**Process graph (one variant, proven before release).**

- `Sportcut.app` (Flutter) calls a Swift platform channel
  `FlutterMethodChannel("sportcut/service")` implemented by
  `SportcutXPCClient.swift`. That client owns one `NSXPCConnection` to
  `Contents/XPCServices/SportcutService.xpc`.
- The XPC target is a separate signed Mach-O. **The Rust backend is linked into
  the XPC target as a static library**: a dedicated staticlib crate,
  `core/adapters/xpc-bridge`, depends on `sportcut-service` and `sportcut-api`
  (which stays an `rlib`) and is linked behind the Swift/ObjC shim. It is not a third
  process and it is not linked into the Flutter executable. The shim contains
  framing and XPC plumbing only; it contains no engine, catalog, or custody
  logic.
- The XPC exported interface is one method,
  `send(_ request: Data, reply: @escaping (Data?, Error?) -> Void)`, and one
  notification path, `notificationHandler`. Frames are the same 4-byte
  length-prefixed JSON objects inside `NSData`; framing, methods, params,
  results, errors, and notifications are identical to the Unix-socket
  transport.
- If static linking is rejected during the packaging spike, the alternative is
  an XPC relay that forwards frames to the `Contents/Helpers/SportcutService`
  process over the same Unix socket. That variant has a third process and a
  socket path, so it is a different process graph with its own smoke test. Do
  not mix the two.

**Container and state-root access.**

- The app, the XPC target, and (in the relay variant) the helper must share one
  writable root. The preferred mechanism is an App Group
  `group.com.sportcut.shared`: all three targets carry
  `com.apple.security.application-groups` with that value, and the service
  state root is the group container's `Sportcut` directory
  (`~/Library/Group Containers/group.com.sportcut.shared/Sportcut`). A group
  container path is longer than the sandbox container path, so the 103-byte
  endpoint check applies and the endpoint must be a short path inside the group
  container (for example `<group-container>/run/s.sock`) if the full path would
  not fit.
- The alternative is `com.apple.security.inherit` for the XPC target, which
  makes it run in the app's sandbox and container. This is simpler but must be
  proven for the XPC launch shape, not assumed from the helper case.
- The chosen mechanism is recorded with the XPC smoke test. The app still has
  no Rust library, no FFI, and no dylib.
- App Store review expects the sandbox, no private APIs, no downloaded code,
  and a clear purpose string for user-selected file access.

**Proof gate.** Before the XPC path is claimed as viable, a sandboxed smoke test
must launch the notarizable XPC build, complete the handshake, import through
the chosen handoff, read the playback path, run one export, and survive an XPC
crash/relaunch. Until then it remains a fallback and Q-1 stays open.

### 9.3 Entitlements summary

| Target | Entitlement | Value | Why |
| --- | --- | --- | --- |
| App | `com.apple.security.app-sandbox` | true | Store requirement and defense-in-depth |
| App | `com.apple.security.files.user-selected.read-only` | true | Open panel for the recording |
| App | `com.apple.security.files.bookmarks.app-scope` | true when the bookmark path is enabled | Create the security-scoped bookmark the helper resolves. Use `document-scope` instead if that scope is chosen |
| App | `com.apple.security.network.server` | removed | No local server is needed by the app |
| Helper | `com.apple.security.app-sandbox` | true | Runs sandboxed |
| Helper | `com.apple.security.inherit` | true | Inherits the app's sandbox and container |
| Helper | `com.apple.security.files.user-selected.read-only` | true when the bookmark path is enabled | Read the picked recording for custody |
| Helper | `com.apple.security.files.bookmarks.app-scope` | true when the bookmark path is enabled | Resolve the app-created bookmark. Not implied by `inherit` |
| App, helper, XPC (relay/static variants) | `com.apple.security.application-groups` | `group.com.sportcut.shared` when the XPC path uses an App Group | Share one writable state root; omit if `inherit` is proven for the XPC target |
| XPC target | `com.apple.security.app-sandbox` | true | Runs sandboxed |
| XPC target | `com.apple.security.inherit` or an App Group | one, proven by smoke test | Container and state-root access; the choice is recorded |
| XPC target | `com.apple.security.files.user-selected.read-only` and `com.apple.security.files.bookmarks.app-scope` | true when the bookmark path is enabled | Resolve and read the app-created bookmark in the XPC-hosted backend |
| Both | hardened runtime | enabled | Notarization requirement |
| Both | `com.apple.security.cs.disable-library-validation` | not used | No need to load unsigned libraries |

### 9.4 Media toolchain and inference asset packaging

- `ffmpeg` and `ffprobe` are separate executables inside the helper's resources
  or the app bundle's `Contents/Resources/MediaTools`, signed and notarized with
  the app.
- The launcher passes them with `--ffmpeg` and `--ffprobe`. When a flag is
  absent the media pipeline honors `SPORTCUT_FFMPEG`/`SPORTCUT_FFPROBE` when
  set, then falls back to `PATH` discovery; both are development shapes only. A
  packaged build passes the bundle paths so the service never depends on a
  developer or user environment. The service owns this discovery and publishes
  an explicitly passed tool path to the media use case
  (`sportcut-media`, `core/use-cases/media`).
- `ffmpeg` and `ffprobe` are required at runtime. The inference assets are
  optional: a bundle without them still imports, analyses, and exports, and
  `service.health` reports `vision.available: false` (with `assetsPresent`
  distinguishing absent assets from a present but unsupported model) and an
  actionable `detail`.
- The inference runtime and person model are packaged in the bundle
  (`Contents/Frameworks/libtensorflowlite_c.dylib` and
  `Contents/Resources/model.tflite`) and are resolved by the service, not the
  client. Resolution precedence is `--tflite-library`/`--person-model`, then the
  bundle files, then `SPORTCUT_TFLITE_LIBRARY`/`SPORTCUT_PERSON_MODEL`.
  `tools/embed-inference-assets.sh` copies the fetched assets into those
  locations.
- The dev GPL build remains non-shippable (BRD R-2). The helper architecture
  does not change that licensing decision; it only changes where the tool is
  launched from.
- A sandboxed child process may need its own inheritance entitlement; sign the
  media tools with the same Team ID and verify them at launch.

### 9.5 Distribution matrix

| Channel | Transport | Sandbox | Helper location | Status |
| --- | --- | --- | --- | --- |
| Developer ID + notarization | Unix socket | App Sandbox on | `Contents/Helpers` | Primary |
| Mac App Store | XPC | App Sandbox on | `Contents/XPCServices` | Fallback |
| Local development | Unix socket | Sandbox off or on | `core/target/release` via `--service-bin` | Dev only, never shipped |

## 10. Error, health, and observability

### 10.1 Error model

The engine error type `SportcutError` lives in `sportcut-common`
(`core/entities/common`); the service adapter (`core/adapters/service`) maps it
to the protocol. Every failure maps to a stable protocol code and a structured
`data` object:

| Source `SportcutError` | Protocol kind | Code | Retryable |
| --- | --- | --- | --- |
| `Io` | `io` | `-32020` | Sometimes; details name the path |
| `InvalidInput` | `invalid_input` | `-32602` | No |
| `Unsupported` | `unsupported` | `-32022` | No |
| `ToolchainUnavailable` | `toolchain_unavailable` | `-32023` | Yes, after fixing the install |
| `MediaToolFailed` | `media_failed` | `-32024` | Sometimes |
| `Probe` | `probe_failed` | `-32025` | No |
| `Artifact` | `artifact` | `-32026` | Sometimes |
| `JobRejected` | `job_rejected` | `-32030` | No, until the other job ends |
| `JobFailed` | `job_failed` | `-32031` | Sometimes |
| `Cancelled` | `cancelled` | `-32032` | Not an error at the job level |
| Catalog not found | `not_found` | `-32040` | No |
| Catalog conflict | `conflict` | `-32041` | No |
| Unknown job | `job_not_found` | `-32042` | No; re-run |
| Unauthorized | `unauthorized` | `-32000` | No |
| Version mismatch | `version_mismatch` | `-32001` | No; use the bundled service |
| Internal | `internal` | `-32603` | Maybe |

Every error carries:

- `message`: diagnostic, may name a file and reason;
- `data.kind`: the stable kind above;
- `data.retryable`: boolean;
- `data.userMessage`: safe, short, verb-first copy for the UI;
- `data.stage` and `data.jobId` when the error belongs to a job;
- `data.details`: optional structured context, never secrets.

The client maps all of these to one `ServiceException` type with `kind`,
`userMessage`, and the protocol code. UI code never parses a diagnostic string
to decide what to do.

### 10.2 Health

`service.health` returns:

- service version, protocol version, instance ID, PID, uptime;
- catalog schema version and migration state;
- state root and free disk space;
- media toolchain availability and versions (`toolchain`: `available`,
  `ffmpeg`, `ffprobe`, `version`, or `detail`);
- vision availability: `available` (runnable), `assetsPresent`, `runtimePath`,
  `modelPath`, `modelFingerprint`, and an actionable `detail`. `available` is
  true only when the build has `macos-tflite-eval`, both files exist, and the
  model matches the pinned EfficientDet-Lite0 trial fingerprint the tracking job
  enforces, so a present-but-unsupported model cannot report healthy;
- running jobs and queued admission state;
- last error summary, if any.

The service reports `degraded`, not `not_ready`, when the media toolchain or the
vision assets are unavailable: the work that does not need them still runs. A
missing feature or asset is `vision.detail` naming the fix. A build without
`macos-tflite-eval` — including every non-macOS build — therefore reports
`degraded` permanently; that is the expected representation of an optional
capability, not a service fault. The client uses the health response for the
status bar and for an actionable "service not ready" state. It is a local call
and adds no network surface.

### 10.3 Logging and diagnostics

- Structured JSON lines to `<state-root>/logs/service.log`, rotating at 10 MiB
  with five retained files.
- Log levels: `error`, `warn`, `info`, `debug`. Release default is `info`.
- Every request has a correlation ID; job logs include `jobId` and `matchId`.
- Tokens are redacted. The service does not log file contents.
- No telemetry, no remote logging, no crash upload. Diagnostics stay on the
  device.
- A "copy diagnostics" action calls `service.diagnostics`; the service builds
  the local bundle containing the log tail, health snapshot, and version
  matrix, with paths redacted if the user chooses, and returns the bundle path.
  The client does not read `<state-root>/logs/` directly, and the handshake
  does not grant that access.

## 11. Performance

| Concern | Target and approach |
| --- | --- |
| Service cold start | Under 500 ms p95 to handshake on an Apple Silicon Mac; SQLite open and schema check happen before readiness |
| Small RPC latency | Under 5 ms p95 local round trip for catalog reads and job status |
| Large payloads | Player-track windows are bounded; a response over 16 MiB is rejected with `response_too_large` and a narrower-window hint |
| Progress overhead | Coalesced to at most 20 notifications/s per job; status polls always available |
| Import | The recording is copied once in the service. The bookmark path sends no recording bytes over the protocol; the inbox handoff copies once into the service and deletes the inbox file after custody |
| Export | The service launches `ffmpeg` once; progress is reported by stage |
| Memory | One service heap; no duplicate catalog or recording in the client |
| CPU | One heavy job at a time, preserving the existing admission policy |
| Startup UX | The app can render the shell before the service is ready and show a labelled connecting state |
| Disk | WAL mode for the catalog; `busy_timeout`; `foreign_keys = ON`; one writer connection; indexes unchanged |

Performance is measured with fixtures, not guessed. The migration exit gates
include a comparison against the FFI baseline for probe, manifest read, job
start, and a track-window read.

## 12. Testing

| Layer | What is tested |
| --- | --- |
| Rust unit | Framing, auth, error mapping, catalog CRUD, recording copy, path validation, migrations |
| Protocol conformance | Golden request/response fixtures, unknown-field tolerance, version negotiation, oversize frames, malformed JSON, duplicate IDs |
| Engine integration | The existing `core/adapters/api/tests` and crate tests run unchanged behind the service |
| Catalog migration | A v5 fixture database with workspaces, matches, rallies, scores, clips, and settings migrates to v6 with byte-for-byte row equality |
| Recording migration | Existing `SportcutRecordings` move or copy with digest checks; cancelled and disk-full paths leave nothing partial |
| Parity | Recorded FFI DTO corpus replayed over the protocol produces equal results |
| Client | Protocol client against an in-process fake server; widget tests with a fake repository; no native library |
| Failure injection | Service kill mid-job, disconnect mid-request, disk full, corrupt catalog, missing ffmpeg, stale socket |
| Packaging | Codesign, `spctl`, notarization, sandbox launch, helper launch, helper crash |
| Performance | Cold start, small RPC p95, track-window bound, import copy throughput |
| Offline | The existing offline test plus a check that the service opens no network socket |

The engine's own suite stays runnable without Flutter, Xcode, or JDK, including
`tools/check-layering.sh` over the layer directories.

## 13. Versioning

- The protocol has an independent semantic version: `major.minor`.
- The service and client are bundled together in v1 and must agree on the
  major version. A mismatch returns `version_mismatch` and the app offers the
  bundled service as the fix.
- The minor version is backward compatible: additive methods, additive fields,
  additive enum values, and advisory capabilities.
- The client sends its supported protocol range and capability set in
  `service.hello`; the service responds with the selected version and the
  methods it can serve.
- The catalog schema version is independent of the protocol version. Catalog
  schema v6 is the target; future migrations are additive and versioned.
- Artifact schemas remain versioned as today: manifest 3, checkpoint 1,
  calibration 1, tracks 1, rally suggestions 1.
- A service-only update is not a v1 feature. If it is added later, the same
  major/minor rules apply and the app must handle an older service.

## 14. Deployment

- Build the service as a universal Rust binary in CI:
  `cargo build --release --target aarch64-apple-darwin` and the `x86_64`
  target, then `lipo`.
- Build the Flutter app, copy the service into `Contents/Helpers`, copy the
  media tools, sign inside-out, and notarize the bundle.
- Produce a `.dmg` or `.pkg` for Developer ID distribution and a `.pkg` for the
  App Store variant.
- The service version is the app version plus a build identifier; it is visible
  in `service.health` and in the diagnostics bundle.
- Rollback is an app-version rollback. The catalog backup and the copy-first
  recording migration make the rollback safe within the documented window.
- The release checklist includes the no-Rust-in-app checks, the protocol
  conformance suite, the catalog migration fixture, and a sandbox smoke test.

## 15. No-Rust-in-app enforcement

The rule is not a code-review convention; it is a CI gate. The check script
`tools/check-no-rust-in-app.sh` runs on every pull request and in the release
job. It fails when any of the following is true.

### 15.1 Source checks

```bash
# No FFI package or generated bindings in the client.
! grep -R "flutter_rust_bridge" app/pubspec.yaml app/pubspec.lock app/lib
! test -d app/lib/src/bridge/generated
! grep -R "dart:ffi" app/lib
! grep -R "DynamicLibrary" app/lib
! grep -R "ExternalLibrary" app/lib
! grep -R "RustLib" app/lib

# No bridge-only Rust configuration.
! grep -R "flutter_rust_bridge" core/Cargo.toml core/adapters/api/Cargo.toml
! test -f flutter_rust_bridge.yaml
! test -f core/adapters/api/src/frb_generated.rs
! grep -Eq 'crate-type[[:space:]]*=[[:space:]]*\[[^]]*"(cdylib|staticlib)"' core/adapters/api/Cargo.toml
! grep -q '^bridge = ' core/adapters/api/Cargo.toml

# The Flutter app target must not consume a Rust archive. In the XPC variant a
# separate XPC target may build the staticlib crate core/adapters/xpc-bridge;
# that archive is linked into the XPC executable and never copied into the app
# or its frameworks.
! find app -name '*.a' -path '*sportcut*' -not -path '*/XPCServices/*' -print -quit | grep -q .

# The narrow unsafe allowance is confined to the OS-glue module.
! grep -RIn --include='*.rs' '\bunsafe\b' core | grep -v '/os_glue'
```

### 15.2 Build-graph checks

- The service binary is the only Rust artifact shipped:
  `find Sportcut.app \( -name 'libsportcut_api.*' -o -name '*.dylib' -o -name '*.a' \) | grep -i sportcut`
  returns nothing.
- `otool -L Sportcut.app/Contents/MacOS/sportcut` lists no Sportcut Rust
  library.
- `otool -L Sportcut.app/Contents/Helpers/SportcutService` lists only system
  libraries and its own media tools, not the Flutter framework.
- `codesign -dv --verbose=4` shows the app and helper signed with the same Team
  ID; the helper has its own signature and is not `dlopen`ed.
- **Stripped-binary check.** The release profile sets `strip = true`, so
  `nm` on the shipped app binary can report no symbols and pass vacuously. The
  gate therefore also builds a `ci-check` profile with `strip = false` and runs:
  - `nm -u` on the unstripped app executable, which must show no `sportcut_`
    undefined symbols;
  - a sentinel `#[no_mangle] pub extern "C" fn sportcut_rust_sentinel()` in the
    service binary, which `nm SportcutService` must find and `nm` on the app
    must not. The sentinel proves the check can observe Rust symbols rather
    than passing because the symbol table is empty.
- `strings Sportcut.app/Contents/MacOS/sportcut` has no `flutter_rust_bridge`
  marker.
- `cargo tree -p sportcut-api` shows no FRB dependency, and the app build
  invokes no Cargo command.
- The app's `pubspec.lock` has no `flutter_rust_bridge`; the app's dependencies
  are Dart/Flutter packages only.

### 15.3 Runtime checks

- Launch the app under the sandbox; the helper appears as a separate PID.
- Quit the app; the helper exits within the documented grace period or after
  finishing its job.
- Kill the helper; the UI shows a service error and recovers by relaunching.
- `lsof -p <helper-pid>` shows no network sockets, only the Unix socket and
  local files.
- `lsof -p <app-pid>` shows no `libsportcut_api.dylib`.

### 15.4 Review checks

- `app/README.md`, `CLAUDE.md`, and `docs/` do not instruct anyone to run
  `tools/generate-bridge.sh`, `tools/build-engine-lib.sh`, or
  `tools/embed-engine-lib.sh` for the shipping path. The docs update lands in
  the same change that flips the default transport, not only at Phase 5; this
  check runs from that change onward.
- The only supported engine entry points are the service executable and the
  protocol client.
- Client code and docs do not pass or instruct `runtimePath`/`modelPath` on
  `engine.tracking.start`: inference assets are resolved and owned by the
  service.
- Any new native client dependency is reviewed against the no-Rust-in-app rule
  and recorded in the dependency register.
