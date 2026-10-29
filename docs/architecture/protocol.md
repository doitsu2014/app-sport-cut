# Sportcut Service Protocol v1

| Field | Value |
| --- | --- |
| Status | Proposed |
| Date | 2026-10-29 |
| Version | 1.0 |
| Transport | Unix domain socket (primary), XPC (fallback) |
| Encoding | UTF-8 JSON |
| Decision | [ADR-0001](../adr/0001-rust-background-service.md) |
| Runtime architecture | [Background service architecture](background-service.md) |
| Requirements | [Product context](../brd/00-product-context.md) |

This document is the wire contract between the Flutter macOS studio and the
Rust background service. It is the only channel between them. The client has no
database, no recording custody, no FFI, and no direct access to the service's
files except the paths the protocol returns for playback, render inputs, and a
service-built diagnostics bundle. The client never reads the service log tree
directly; it calls `service.diagnostics`.

## 1. Transport and framing

### 1.1 Primary transport

- `AF_UNIX`, `SOCK_STREAM`.
- Endpoint: the launcher passes `--endpoint <path>`; the service creates it. The
  default is **not** `<state-root>/run/service.sock`, because that path exceeds
  macOS `sockaddr_un.sun_path` (104 bytes including the NUL terminator) once the
  App Sandbox container prefix is included. The defaults are:

  | Context | Default endpoint | Example length |
  | --- | --- | --- |
  | App Sandbox / App Store | `<container>/Data/run/s.sock` | `/Users/ana/Library/Containers/com.sportcut.sportcut/Data/run/s.sock` = 66 bytes |
  | Developer ID, non-sandboxed support build | `~/Library/Application Support/Sportcut/run/service.sock`, only if it fits | 64 bytes for `ana` |
  | Test and custom layouts | explicit `--endpoint` | must fit |

  `<container>` is the app container root
  (`~/Library/Containers/com.sportcut.sportcut`), not the state root. The
  endpoint must remain inside the app container or the state root so the app
  can reach it under the sandbox.
- Before binding, the service computes the UTF-8 byte length of the endpoint
  path, excluding the NUL terminator. If it exceeds 103 bytes, it refuses to
  start with `endpoint_too_long`, prints the computed path, its byte length, and
  the 103-byte limit, and opens no socket. It never silently truncates or falls
  back to another path. A sandboxed test binds and connects on the exact default
  path.
- The directory is mode `0700`; the socket and token file are mode `0600`.
- The service verifies the peer UID on accept (`getpeereid` or
  `LOCAL_PEERCRED`). A different UID is disconnected before any bytes are read.
- No TCP listener and no network entitlement. The service opens no network
  socket at any point.
- The Dart client connects with
  `Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0)`.
  `dart:io` supports `AF_UNIX` on macOS; no package and no `dart:ffi` is used.

### 1.2 Fallback transport

- XPC (`NSXPCConnection`) for the Mac App Store packaging variant.
- The same JSON message is carried as one `NSData` payload. The framing below
  applies inside the payload.
- A thin transport shim moves bytes and file descriptors. It contains no
  engine, catalog, or custody logic.
- Method names, params, results, errors, and notifications are identical to the
  Unix-socket transport.

### 1.3 Framing

Every message is one frame:

```text
+----------------------+----------------------------------------+
| 4-byte unsigned int  | JSON payload, UTF-8, no trailing byte  |
| big-endian length N  | N bytes                                |
+----------------------+----------------------------------------+
```

- `N` is the payload length in bytes, not including the 4-byte prefix.
- `N` must be greater than 0 and at most **16 MiB** (16,777,216 bytes).
- A frame with `N = 0`, `N > 16 MiB`, or invalid UTF-8 closes the connection
  with a `frame_too_large` or `parse_error` frame when a response can still be
  sent; otherwise the connection is closed.
- The payload must be a JSON object. Arrays, scalars, and batches are invalid.
- Newline framing is not used. Do not use `readLine`.
- The receiver reads the prefix, then exactly `N` bytes. It does not scan for a
  delimiter.

### 1.4 Message model

The protocol is a JSON-RPC 2.0 subset.

- Requests: `{"jsonrpc":"2.0","id":...,"method":"...","params":{...}}`.
- Responses: `{"jsonrpc":"2.0","id":...,"result":{...}}` or
  `{"jsonrpc":"2.0","id":...,"error":{...}}`.
- Notifications: `{"jsonrpc":"2.0","method":"...","params":{...}}` with no
  `id`.
- `id` is a string or an integer, unique per connection while in flight. A
  request `id` must not be `null`.
- Batch requests are not supported (`-32600`).
- Extra members on requests and responses are ignored.
- A response to an unknown or already-completed `id` is ignored by the client.

### 1.5 Connection lifecycle

1. Connect.
2. Send `service.hello` as the first frame.
3. Receive a successful `service.hello` result.
4. Send requests and receive responses and notifications.
5. Close, or send `service.shutdown`.

Any method other than `service.hello` before a successful handshake returns
`handshake_required` and the connection is closed. A second `service.hello` on
the same connection returns `invalid_input`.

The client may pipeline requests. Responses may arrive out of order; the `id`
correlates them. Notifications may interleave with responses.

## 2. Handshake and version negotiation

### 2.1 Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "service.hello",
  "params": {
    "protocol": { "major": 1, "minor": 0 },
    "client": {
      "name": "Sportcut.app",
      "version": "0.1.0",
      "build": "20261029.1"
    },
    "token": "b7f0c2a4e5d64f0a9c1e2d3b4a5c6d7e",
    "capabilities": [
      "engine.v1",
      "catalog.v1",
      "custody.v1",
      "notifications.v1"
    ]
  }
}
```

### 2.2 Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "service": {
      "name": "sportcutd",
      "version": "0.1.0",
      "build": "20261029.1",
      "instanceId": "0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978",
      "pid": 48213
    },
    "protocol": { "major": 1, "minor": 0 },
    "catalog": {
      "schemaVersion": 6,
      "owner": "service",
      "adoptedFrom": "v5"
    },
    "stateRoot": "/Users/ana/Library/Containers/com.sportcut.sportcut/Data/Library/Application Support/Sportcut",
    "endpoint": "/Users/ana/Library/Containers/com.sportcut.sportcut/Data/run/s.sock",
    "paths": {
      "recordings": "/.../Sportcut/recordings",
      "matches": "/.../Sportcut/matches",
      "renderInputs": "/.../Sportcut/render-inputs"
    },
    "capabilities": [
      "engine.v1",
      "catalog.v1",
      "custody.v1",
      "notifications.v1",
      "idempotency.v1",
      "playback.path.v1",
      "diagnostics.v1"
    ],
    "limits": {
      "maxFrameBytes": 16777216,
      "maxInFlightPerConnection": 64,
      "maxConnections": 8,
      "progressPerSecond": 20,
      "trackWindowDefaultSeconds": 60,
      "trackWindowMaxSeconds": 300,
      "requestTimeoutMs": 30000,
      "endpointMaxBytes": 103
    }
  }
}
```

### 2.3 Version rules

- The client sends the protocol version it speaks.
- The service supports one major version at a time. If `major` differs, it
  returns `version_mismatch` with `data.supported` and closes the connection.
- Within the same major, the service selects `min(client.minor, service.minor)`.
  The selected minor is the effective version for the connection.
- A newer client may use only capabilities the service listed. It must not
  assume a higher minor's methods exist.
- A newer service may accept an older client; every method and field the older
  client knows must keep working.
- The client presents its capability set; the service intersects it and returns
  the served set. A method whose capability is not in the intersection returns
  `method_not_found`.

### 2.4 Authentication

- `params.token` is compared with the token file in constant time.
- A missing or wrong token returns `unauthorized` and closes the connection.
- The token is regenerated by the app on every launch and is never persisted in
  the catalog, logged, or placed in a user-visible message.
- The same-UID peer check is independent of the token and runs first.

## 3. Request, response, and notification shapes

### 3.1 Request fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `jsonrpc` | string | Yes | Exactly `"2.0"` |
| `id` | string or integer | Yes for requests | Correlation identifier |
| `method` | string | Yes | Method name from the tables below |
| `params` | object | Yes | Method parameters; may be `{}` |
| `clientRequestId` | string | No | Idempotency key for mutating methods |

`clientRequestId` is a top-level extension member. It is not part of
`params`. A client-generated UUID is recommended. The service keeps the result
of the last 1,024 mutating requests for 10 minutes and returns the same result
for a repeated key instead of performing the mutation twice.

**Long-running mutations.** A mutation that starts a job
(`library.match.import`, `library.catalog.adoptLegacy`) persists its key and
result in the service job registry on disk, not only in the in-memory cache:

- The key maps to the job handle and the created entity until the job has
  reached a terminal state **and** the created entity (the match or the adopted
  library marker) is deleted or superseded. It survives a service restart.
- A retry with the same key after the client lost the response, or after a
  service restart, returns the existing `importId`/`jobId` rather than starting
  a second copy.
- If a key is unknown, the service starts a new mutation. Before retrying an
  import whose key may have been evicted, the client reads `library.match.list`
  (optionally filtered by the original source path) and reconciles; it must not
  blindly re-import a multi-gigabyte recording.
- The 1,024-entry / 10-minute cache remains the bound for lightweight
  mutations; it is not the bound for job-starting mutations.

### 3.2 Response fields

A success response has `id` and `result`. An error response has `id` and
`error`:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32030,
    "message": "job job-7 was rejected: another resource-intensive job (job-6) is already running; only one runs at a time",
    "data": {
      "kind": "job_rejected",
      "retryable": false,
      "userMessage": "Another analysis job is running. Wait for it to finish or cancel it.",
      "details": { "runningJobId": "job-6" }
    }
  }
}
```

`message` is diagnostic and may name a file and reason. `data.userMessage` is
the only field the UI should show as-is. `data.kind` and the code are the stable
contract; never parse `message` to decide behavior.

### 3.3 Notification fields

Notifications have no `id`. They are fire-and-forget, but the authoritative
state is always available through a status or read method.

| Method | When | Params |
| --- | --- | --- |
| `job.progress` | A job reports progress | `jobId`, `matchId`, `state`, `stage`, `value`, `message`, `seq`, `completedStages` |
| `job.state` | A job changes lifecycle state | `jobId`, `matchId`, `state`, `stage`, `error`, `completedStages`, `seq` |
| `catalog.changed` | A catalog mutation commits | `entities`, `matchId`, `workspaceId`, `revision` |
| `service.shutdown` | The service is about to exit | `reason`, `deadlineMs` |

`seq` is a per-job strictly increasing integer. A client that sees a gap must
re-read `engine.job.status`; it must not assume a missed update.

## 4. Method table: service lifecycle

| Method | Params | Result | Notes |
| --- | --- | --- | --- |
| `service.hello` | `protocol`, `client`, `token`, `capabilities` | service/protocol/catalog/paths/limits | Must be first |
| `service.health` | `{}` | `status`, versions, catalog state, disk free, toolchain, vision, jobs | Callable while a heavy job runs |
| `service.info` | `{}` | Build metadata, state root, protocol range | Static-ish |
| `service.metrics` | `{}` | In-memory counters (optional, `metrics.v1`) | No telemetry; local only |
| `service.ping` | `{}` | `{ "pong": true, "uptimeMs": 1234 }` | Cheap liveness |
| `service.diagnostics` | `redactPaths?` | `{ "bundlePath": "...", "createdAt": 1761782400000 }` | Builds the local diagnostics bundle; the client never reads `logs/` directly |
| `service.shutdown` | `cancelRunningJobs`, `reason` | `{ "accepted": true }` then `service.shutdown` notification | Closes the connection |

`service.health` reports two availability blocks:

```json
{
  "toolchain": {
    "available": true,
    "ffmpeg": "/.../MediaTools/ffmpeg",
    "ffprobe": "/.../MediaTools/ffprobe",
    "version": "ffmpeg version 7.1"
  },
  "vision": {
    "available": false,
    "assetsPresent": true,
    "runtimePath": "/.../Frameworks/libtensorflowlite_c.dylib",
    "modelPath": "/.../Resources/model.tflite",
    "modelFingerprint": "fnv1a64:0a4c9e64faa2dae8",
    "detail": "this build lacks the macos-tflite-eval feature; rebuild sportcut-service with --features macos-tflite-eval"
  }
}
```

- `toolchain.available` is false when `ffmpeg`/`ffprobe` cannot be resolved;
  `detail` then names the problem. `ffmpeg`/`ffprobe` are required for probe,
  proxy, audio, frames, and export.
- `vision.available` means *runnable*: the build has the `macos-tflite-eval`
  feature, both service-owned assets resolve to files, **and** the model matches
  the pinned EfficientDet-Lite0 trial fingerprint the tracking job enforces.
  `assetsPresent` reports file presence alone, so a present-but-unsupported
  model is distinguishable. `runtimePath`, `modelPath`, `modelFingerprint`, and
  `detail` are present in the object; an absent path is `null`. A missing
  feature, a missing asset, or an unsupported model makes player tracking
  unavailable but does not stop other work.
- Either block being unavailable sets `status` to `degraded`, not `not_ready`,
  as long as the state root and disk are healthy. A build without
  `macos-tflite-eval` is expected to stay `degraded`; that is an optional
  capability, not a fault.

## 5. Method table: engine facade

The 17 calls of `core/crates/api/src/facade.rs` map one-to-one. The wire uses
`matchId`, not a client-chosen `matchDir`; the service resolves the match
directory from its state root and the catalog. This is the only parameter-shape
adaptation, and it removes a path-confusion class. The service accepts an
explicit `matchDir` only in development builds and only when it resolves under
the state root.

| # | Protocol method | Facade function | Params | Result |
| --- | --- | --- | --- | --- |
| 1 | `engine.importStages` | `media_import_stages` | `{}` | `{ "stages": ["probe","proxy","audio","frames"] }` |
| 2 | `engine.probe` | `probe_media` | `source` (`path` or `bookmark`) | `MediaMetadata` |
| 3 | `engine.import.start` | `start_import` | `matchId`, `samplingRate` | `JobHandle` |
| 4 | `engine.regenerate.start` | `start_regenerate_match_media` | `matchId`, `samplingRate` | `JobHandle` |
| 5 | `engine.rally.start` | `start_rally_segmentation` | `matchId`, `config` | `JobHandle` |
| 6 | `engine.rally.suggestions` | `match_rally_suggestions` | `matchId`, `config` | `RallySuggestions` or `null` |
| 7 | `engine.tracks.window` | `match_player_tracks` | `matchId`, `startSeconds`, `endSeconds` | `PlayerTracks` or `null` |
| 8 | `engine.tracking.start` | `start_player_tracking` | `matchId`, `config` | `JobHandle` |
| 9 | `engine.job.status` | `job_status` | `jobId` | `JobStatus` |
| 10 | `engine.highlight.rank` | `rank_highlights` | `{ "rallies": [HighlightRally] }` | `{ "rallies": [HighlightRank] }` |
| 11 | `engine.servingSides` | `serving_sides` | `{ "rallies": [RallyOutcome] }` | `{ "rallies": [ServingSide] }` |
| 12 | `engine.court.geometry` | `court_geometry` | `segment` | `CourtGeometry` |
| 13 | `engine.calibration.save` | `save_match_calibration` | `matchId`, `calibration` | `CalibrationSave` |
| 14 | `engine.calibration.get` | `match_calibration` | `matchId` | `CourtCalibration` or `null` |
| 15 | `engine.job.cancel` | `job_cancel` | `jobId` | `JobStatus` |
| 16 | `engine.export.start` | `export_highlight` | `matchId`, `clips`, `leadInSeconds`, `leadOutSeconds`, `title?`, `musicPath?`, `musicGain` | `JobHandle` |
| 17 | `engine.manifest` | `match_manifest` | `matchId` | `ArtifactManifest` |

Notes:

- `engine.import.start` reads the recording from the service-owned recording
  store. The client must have created the match through `library.match.import`
  first; an unknown `matchId` returns `not_found`.
- `engine.tracking.start` does **not** accept `runtimePath` or `modelPath`.
  Inference assets are service-owned: the service resolves its own TFLite
  runtime and person model at startup (from `--tflite-library`/`--person-model`,
  the app bundle, or `SPORTCUT_TFLITE_LIBRARY`/`SPORTCUT_PERSON_MODEL`). A
  request that supplies either field is rejected with `invalid_params` and a
  message stating the service-owned rule. A build without the
  `macos-tflite-eval` feature returns `unsupported` naming the feature; use
  `service.health` `vision` for the current availability and paths.
- `engine.calibration.save` writes the artifact and the catalog copy in the
  service; the client no longer writes a second copy. The result still names
  `changed`, `invalidatedKinds`, and `geometry` in the same order.
- `engine.export.start` resolves `sourcePath` from the catalog. Overlay and
  title images are paths inside
  `<state-root>/render-inputs/<uuid>/`; the service deletes the directory when
  the job reaches a terminal state.
- `engine.job.status` returns `completedStages` from the checkpoint file exactly
  as today.
- `engine.importStages` is the stage list the UI renders; it is served by the
  service so the two sides cannot drift.

### 5.1 Engine DTOs

The protocol uses the existing DTO fields with camelCase names. Enums use the
existing lower-snake-case values. Representative shapes:

```json
// MediaMetadata
{
  "path": "/.../recordings/match-1/clip.mp4",
  "durationSeconds": 1234.5,
  "frameRate": 29.97,
  "width": 1920,
  "height": 1080,
  "rotationDegrees": 0,
  "orientation": "landscape",
  "hasAudio": true,
  "sizeBytes": 987654321
}
```

```json
// JobHandle
{ "jobId": "job-1", "matchId": "match-1" }
```

```json
// JobStatus
{
  "jobId": "job-1",
  "matchId": "match-1",
  "state": "running",
  "stage": "proxy",
  "progress": { "stage": "proxy", "value": 0.42, "message": "encoding proxy" },
  "error": null,
  "completedStages": ["probe", "audio"]
}
```

```json
// ArtifactManifest
{
  "matchId": "match-1",
  "originalPath": "/.../recordings/match-1/clip.mp4",
  "artifacts": [
    { "kind": "proxy", "relativePath": "proxy/proxy.mp4", "state": "final", "sizeBytes": 12345 }
  ],
  "missingKinds": ["tracks"],
  "notRebuildableKinds": ["calibration"],
  "originalPresent": true
}
```

`JobState` values: `pending`, `running`, `completed`, `cancelled`, `failed`.
`ArtifactState` values: `final`, `non_final`, `missing`.

## 6. Method table: catalog and recording custody

These methods exist because the service owns the catalog and recording store
under ADR-0001. They replace the client's direct `sqflite` writes and its
`RecordingStore`.

### 6.1 Workspaces and matches

| Method | Params | Result | Notes |
| --- | --- | --- | --- |
| `library.workspace.list` | `{}` | `{ "workspaces": [Workspace] }` | Oldest first |
| `library.workspace.create` | `title?` | `{ "workspace": Workspace }` | Generates id and `createdAt` |
| `library.workspace.update` | `workspaceId`, `title` | `{ "workspace": Workspace }` | Implements FR-LIB-09 rename; title only |
| `library.workspace.delete` | `workspaceId`, `deleteArtifacts?`, `deleteRecording?` | `{ "deletedMatches": 3, "deletedWithErrors": [] }` | Delegates to match deletion rules; partial failures are reported, see below |
| `library.match.list` | `workspaceId?` | `{ "matches": [Match] }` | Newest first; `workspaceId` omitted means all |
| `library.match.get` | `matchId` | `{ "match": Match }` or `null` | |
| `library.match.import` | `source`, `title?`, `workspaceId?` | `{ "importId", "matchId", "jobId" }` | Starts a cancellable custody import |
| `library.match.adopt` | `path`, `sha256`, `sizeBytes` | `{ "importId", "matchId", "jobId" }` | Inbox handoff only; `path` must be `<state-root>/inbox/<uuid>.ready`; the service re-hashes it |
| `library.match.update` | `matchId`, `patch` | `{ "match": Match }` | Only `title` and `workspaceId` are mutable |
| `library.match.delete` | `matchId`, `deleteArtifacts?`, `deleteRecording?` | `{ "deleted": true, "deletedWithErrors": [] }` | Original user file is never touched; partial failures are reported, see below |
| `library.recording.path` | `matchId` | `{ "path": "...", "available": true }` | Playback path |
| `library.recording.available` | `matchId` | `{ "available": true }` | Cheap stat; no engine call |
| `library.recording.relocate` | `matchId`, `source` | `{ "match": Match, "jobId": "job-1" }` | Implements FR-LIB-15 Locate; starts a job, see below. `source` is a bookmark object or `{ "path", "sha256", "sizeBytes" }` for the inbox |

`library.match.import` is an asynchronous job because probing and copying a
multi-gigabyte recording are long:

- It reserves a match id and returns immediately.
- Job stages: `probe`, `copy`, `catalog`. In the Phase 3 interim (below) the
  `catalog` stage is performed by the client and the job reports completion
  after custody; the service catalog insert begins in Phase 4.
- `job.progress` reports bytes copied in `message` and a 0–1 value.
- On success, `library.match.get` returns the match. The catalog insert is the
  last step, after the copy is complete and renamed.
- On cancel or failure, the recording directory is removed and no match row
  exists. A cancelled import leaves nothing partial.
- A repeated `clientRequestId` returns the same `importId` and `jobId`.

**Phase 3 interim (custody before catalog).** The migration lands recording
custody one phase before the catalog moves. In that build the service owns the
recording store and returns a provisional `matchId`; it also keeps a temporary
provisional-match registry (`matchId` → recording path) so
`library.recording.path` and `library.recording.available` work before the
catalog moves. The client still owns the catalog row and writes it through its
existing repository; `library.match.get` returns `null` for a provisional match
on that build. For existing libraries, `library.catalog.adoptLegacy` in Phase 3
copies recordings and artifacts and returns the adopted match ids with their new
paths; the client rewrites its own catalog paths in one transaction. In Phase 4
the same method continues idempotently, adopts the catalog, and the service
becomes authoritative. This is a single-writer interim, not a dual write: the
client writes the catalog, the service writes recordings, and Phase 4 removes
the client write. In the Phase 3 build `service.hello` reports
`catalog: { "schemaVersion": 0, "owner": "client", "adoptedFrom": null }`, and
`library.catalog.status` returns the same fields with
`adoptionState: "pending"`; the `6`/`service`/`v5` values below describe the
Phase 4 target. See
[migration-from-ffi.md §3](migration-from-ffi.md#3-phased-plan).

`library.recording.relocate` satisfies FR-LIB-15 (Locate a missing recording).
It is a job because it validates, probes, and copies:

- The client supplies `source` as a security-scoped bookmark or, when the
  inbox handoff is in use, an inbox path plus `sha256` and `sizeBytes`, which
  the service re-hashes exactly as for `library.match.adopt` (see
  [background-service.md](background-service.md#73-sandbox-file-handoff)).
- Job stages: `probe`, `copy`, `catalog`. The existing recording directory is
  not modified until the copy is complete and renamed.
- The service validates that the source is a readable video, copies it into
  `recordings/<matchId>/` under a `.part` name, and atomically replaces the
  recording. The `matches/<matchId>/` artifacts are retained; stages derived
  from the previous recording are marked non-final, and the client may
  regenerate them.
- The original source file is never modified. A cancel or failure leaves the
  previous recording and catalog row intact.
- The same `clientRequestId` returns the same job; a missing match returns
  `not_found`.

**Deletion ordering and partial failure.** `library.match.delete` and
`library.workspace.delete` remove catalog rows in one transaction, then remove
files. The catalog never keeps a row that points at a file the caller asked to
delete. If a file removal fails, the row is still gone and the result reports
the orphan in `deletedWithErrors` so the service can retry cleanup and the UI
can explain what remains:

```json
{
  "deleted": true,
  "deletedWithErrors": [
    { "path": "/.../recordings/match-1/clip.mp4", "reason": "Permission denied" }
  ]
}
```

An empty list is used when every file was removed. The row is never left
half-deleted. `library.workspace.delete` returns one entry per match with a
file failure, plus `deletedMatches` for matches fully removed.

`Match` shape:

```json
{
  "id": "match-1",
  "title": "Final vs Northside",
  "videoPath": "/.../recordings/match-1/final.mp4",
  "durationSeconds": 1234.5,
  "createdAt": 1761782400000,
  "matchDir": "/.../matches/match-1",
  "workspaceId": "workspace-1",
  "videoWidth": 1920,
  "videoHeight": 1080,
  "frameRate": 29.97,
  "hasAudio": true,
  "originalPath": "/Users/ana/Movies/final.mp4",
  "sourceBytes": 987654321,
  "courtCalibration": null
}
```

`createdAt` is epoch milliseconds UTC. `courtCalibration` is the catalog copy,
or `null`.

### 6.2 Editing records

| Method | Params | Result |
| --- | --- | --- |
| `library.rally.list` | `matchId` | `{ "rallies": [Rally] }` |
| `library.rally.save` | `rally` | `{ "rally": Rally }` |
| `library.rally.delete` | `rallyId` | `{ "deleted": true }` |
| `library.suggestion.list` | `matchId`, `generationId` | `{ "decisions": [SuggestionDecision] }` |
| `library.suggestion.accept` | `matchId`, `generationId`, `candidateId`, `rally` | `{ "decision": SuggestionDecision, "rally": Rally }` |
| `library.suggestion.dismiss` | `matchId`, `generationId`, `candidateId` | `{ "decision": SuggestionDecision }` |
| `library.clip.list` | `matchId` | `{ "clips": [HighlightClip] }` |
| `library.clip.save` | `clip` | `{ "clip": HighlightClip }` |
| `library.clip.delete` | `clipId` | `{ "deleted": true }` |
| `library.clip.reorder` | `matchId`, `clipIds` | `{ "clips": [HighlightClip] }` |
| `library.score.list` | `matchId` | `{ "events": [ScoreEvent] }` |
| `library.score.replace` | `matchId`, `events` | `{ "events": [ScoreEvent] }` |
| `library.exportSettings.get` | `matchId` | `{ "settings": ExportSettings }` or `null` |
| `library.exportSettings.put` | `settings` | `{ "settings": ExportSettings }` |
| `library.renderInputs.allocate` | `{}` | `{ "uuid": "...", "directory": "/.../render-inputs/<uuid>" }` |
| `library.summary.scores` | `{}` | `{ "scores": { "match-1": { "left": 18, "right": 16 } } }` |
| `library.summary.clipCounts` | `{}` | `{ "counts": { "match-1": 12 } }` |

`library.renderInputs.allocate` creates a fresh, empty
`<state-root>/render-inputs/<uuid>/` directory and returns its path. The client
writes overlay and title images there and passes the specific file paths to
`engine.export.start`. The service validates that every render-input path is
inside an allocated directory, deletes the directory when the export job
reaches a terminal state, and sweeps unreferenced `render-inputs/` directories
at startup. The client never constructs the `<uuid>` itself.

Semantics preserved from `EditingStore`:

- `library.rally.save` is update-then-insert, so saving an existing rally does
  not fire `ON DELETE SET NULL` on clips. A duplicate new id is a `conflict`.
- `library.rally.delete` removes the rally's suggestion decisions; clips that
  reference it become detached (`rallyId: null`), not deleted.
- `library.clip.reorder` rewrites `orderIndex` in one transaction.
- `library.score.replace` replaces the event list in one transaction; ids are
  assigned by the service if omitted.
- `library.summary.scores` groups the latest events per match exactly as the
  client did.
- `library.summary.clipCounts` counts selected clips per match.

`Rally` shape:

```json
{
  "id": "rally-1",
  "matchId": "match-1",
  "startSeconds": 41.2,
  "endSeconds": 63.8,
  "winnerSide": "left",
  "status": "confirmed",
  "confidence": 0.81,
  "highlightScore": null
}
```

`HighlightClip` shape:

```json
{
  "id": "clip-1",
  "matchId": "match-1",
  "rallyId": "rally-1",
  "startSeconds": 40.2,
  "endSeconds": 64.8,
  "rank": 3,
  "selected": true,
  "trimStartSeconds": null,
  "trimEndSeconds": null,
  "orderIndex": 0
}
```

`SuggestionDecision` shape:

```json
{
  "id": "decision-1",
  "matchId": "match-1",
  "generationId": "gen-42",
  "candidateId": "candidate-7",
  "decision": "accepted",
  "rallyId": "rally-1",
  "createdAt": 1761782400000
}
```

`decision` is `accepted` or `dismissed`. `rallyId` is `null` for a dismissed
decision. `generationId` and `candidateId` are opaque strings from
`engine.rally.suggestions`; the service does not renumber them.

`ExportSettings` shape:

```json
{
  "matchId": "match-1",
  "resolution": "1080p",
  "frameRate": 30,
  "overlayEnabled": true,
  "titleImagePath": null,
  "musicPath": null,
  "musicGainDb": -6.0,
  "leadInSeconds": 1.5,
  "leadOutSeconds": 2.0,
  "updatedAt": 1761782400000
}
```

`resolution` is one of `720p`, `1080p`, `source`. `musicPath` and
`titleImagePath` are absolute paths; a music file is a caller-supplied path and
must resolve under the state root or be selected through the same
security-scoped handoff as a recording. Null clears the value. The
`library.exportSettings.put` params take one `settings` object with `matchId`
required and the remaining fields optional per the update-in-place rule.

### 6.3 Calibration composite

| Method | Params | Result |
| --- | --- | --- |
| `library.calibration.save` | `matchId`, `calibration` | `{ "match": Match, "engine": CalibrationSave }` |
| `library.calibration.get` | `matchId` | `{ "calibration": CourtCalibration, "source": "catalog" }` or `null` |

`library.calibration.save` writes the artifact first and the catalog second, so
a catalog calibration always has an artifact behind it. A failure leaves the
previous calibration in place. `engine.calibration.save` is the lower-level
call used for parity and engine-only operations; in the service product path it
performs the same two steps.

### 6.4 Legacy adoption

| Method | Params | Result |
| --- | --- | --- |
| `library.catalog.status` | `{}` | `{ "schemaVersion": 6, "owner": "service", "adoptedFrom": "v5", "adoptionState": "pending" }` (state is one of `pending`, `running`, `complete`, `failed`) |
| `library.catalog.adoptLegacy` | `dbPath`, `recordingsRoot`, `artifactsRoot` | `{ "jobId": "job-9" }` |
| `library.catalog.adoptStatus` | `jobId` | `AdoptionStatus` (same shape as `JobStatus`, plus counts) |

`adoptLegacy` starts a **job**; it does not run the copy synchronously. It may
copy an entire user library, so it follows the same start-then-follow rule as
the engine jobs:

- Stages: `backup`, `catalog`, `recordings`, `artifacts`, `rewrite`.
- Progress is reported through `job.progress`, with the current stage and
  entity counts. The client must not hold the request open.
- Cancellation is cooperative and idempotent. A cancelled adoption leaves the
  original database and recordings untouched and removes any temporary copy it
  created.
- The migration checkpoints after each stage in `<state-root>/backups/adoption-<catalog_id>.json`,
  so a service crash resumes from the last completed stage rather than copying
  the library again.
- Idempotency: a second call with the same `clientRequestId` returns the same
  job; a completed adoption returns `adoptionState: complete` and a re-run
  verifies instead of re-copying.
- The job is admitted through the same single-heavy-job rule and is included in
  `service.shutdown` cancellation.

The service:

1. copies the v5 database to `backups/catalog-v5-<timestamp>.sqlite`;
2. opens the copy, adds the v6 `catalog_meta` table, and verifies row counts;
3. copies each recording and artifact directory into the service layout,
   skipping files whose digest already matches, and records the digest in the
   adoption checkpoint;
4. rewrites `video_path` and `match_dir` to the service paths in one
   transaction;
5. reports the counts, the backup path, and the final state through
   `library.catalog.adoptStatus`.

In the Phase 3 build, steps 1 and 4 are performed client-side: the service
copies recordings and artifacts and returns the new paths, and the client
rewrites its own catalog in one transaction. From Phase 4 the service performs
all five steps. The original database and recordings are left in place until the
rollback window closes. A failure at any stage restores the backup and reports
`migration_required`; it never opens a half-adopted database.

`AdoptionStatus` extends `JobStatus` with
`{ "matches": 42, "recordings": 42, "artifacts": 42, "backupPath": "...", "adoptionState": "complete" }`.

## 7. DTO rules

- **Names:** camelCase JSON fields; lower_snake_case enum values.
- **IDs:** opaque UTF-8 strings, 1–128 bytes. Clients must not infer structure.
- **Time:** `*Seconds` are floating-point seconds on the original recording
  timeline; `createdAt` and other timestamps are integer epoch milliseconds UTC
  (`int64`).
- **Numbers:** finite JSON numbers only. `NaN`, `Infinity`, and `-Infinity` are
  invalid. Progress is in `0.0..=1.0`. Scores are non-negative integers.
- **Optionals in responses:** every optional field is present with `null` when
  absent. Clients must tolerate both `null` and an omitted optional field.
- **Optionals in requests:** an omitted optional field means "not supplied".
  There is no implicit "null means clear" except where a method documents it
  (`library.clip.save` trim fields, `library.exportSettings.put` title/music).
- **Unknown fields:** ignored by both sides.
- **Empty values:** use `[]` for an empty list, not `null`. Use `null` for an
  absent scalar or object.
- **Strings:** UTF-8, NFC-normalized user text. The service rejects control
  characters in titles.
- **Paths:** absolute POSIX paths, UTF-8. Caller-supplied paths are accepted
  only for the following, and each is canonicalized and checked against the
  documented root:
  - `source` for import, probe, and relocate (a bookmark object or an inbox
    path);
  - the inbox `path` for `library.match.adopt`, which must be
    `<state-root>/inbox/<uuid>.ready`;
  - files inside a `library.renderInputs.allocate` directory;
  - `dbPath`, `recordingsRoot`, and `artifactsRoot` for
    `library.catalog.adoptLegacy` (the one-time legacy roots);
  - `musicPath` for `engine.export.start`, which must resolve under the state
    root or be handed off through the same security-scoped path as a recording.
  Every other path comes from the service. The list in this rule is the
  authoritative list; a method table that names a path uses one of these.
  Inference assets are not a caller path: the service owns and resolves them,
  and `engine.tracking.start` rejects `runtimePath` and `modelPath`.
- **Binary:** no base64 payloads in v1 except a security-scoped bookmark, which
  is a typed object `{ "kind": "bookmark", "value": "<base64>" }`. Recordings
  and images are file paths. A bookmark is never logged, persisted after its
  operation, or returned in a result.
- **Size limits:** method params are at most 1 MiB except `library.score.replace`
  and `library.clip.reorder` (8 MiB). Responses are at most 16 MiB. A larger
  response returns `response_too_large`; narrow a track window or split a
  request.
- **Version namespace:** these DTOs are `v1`. A breaking change is a new major
  protocol, not a field rename.

## 8. Error codes

| Code | Kind | Meaning | Retryable |
| --- | --- | --- | --- |
| `-32700` | `parse_error` | Frame is not valid JSON | No; fix the client |
| `-32600` | `invalid_request` | Not a valid request object, batch, or bad `id` | No |
| `-32601` | `method_not_found` | Unknown method or capability not negotiated | No |
| `-32602` | `invalid_params` | Missing, malformed, or out-of-range params; also `invalid_input` | No |
| `-32603` | `internal` | Unexpected service failure | Maybe |
| `-32000` | `unauthorized` | Missing/wrong token or different UID | No |
| `-32001` | `version_mismatch` | Protocol major not supported | No; use the bundled service |
| `-32002` | `handshake_required` | First method was not `service.hello` | No; reconnect |
| `-32003` | `frame_too_large` | Frame over 16 MiB or zero length | No; split |
| `-32020` | `io` | Filesystem operation failed | Sometimes |
| `-32022` | `unsupported` | Valid request outside this build | No |
| `-32023` | `toolchain_unavailable` | ffmpeg/ffprobe missing or unusable | Yes, after install |
| `-32024` | `media_failed` | Media tool returned an error | Sometimes |
| `-32025` | `probe_failed` | File could not be read as media | No |
| `-32026` | `artifact` | Manifest or artifact inconsistent | Sometimes |
| `-32027` | `response_too_large` | Result exceeds 16 MiB | No; narrow the request |
| `-32030` | `job_rejected` | Admission control rejected the job | No, until the other job ends |
| `-32031` | `job_failed` | A job stage failed | Sometimes |
| `-32032` | `cancelled` | Cooperative cancellation | Not an error at job level |
| `-32040` | `not_found` | No such match, rally, clip, or workspace | No |
| `-32041` | `conflict` | Duplicate id or conflicting write | No |
| `-32042` | `job_not_found` | Unknown job, often after a service restart | No; re-run |
| `-32043` | `migration_required` | Legacy catalog not adopted yet | Yes, after `adoptLegacy` |
| `-32044` | `catalog_locked` | Another writer holds the catalog | Yes, after backoff |
| `-32045` | `endpoint_too_long` | The Unix socket path exceeds 103 bytes; the service refuses to start | No; pass a shorter `--endpoint` |

Error `data` fields:

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `kind` | string | Yes | Stable kind above |
| `retryable` | boolean | Yes | Whether the same request may succeed later |
| `userMessage` | string | Yes | Safe, short, verb-first UI copy |
| `stage` | string | No | Job stage when relevant |
| `jobId` | string | No | Job when relevant |
| `details` | object | No | Structured context; no secrets |

## 9. Progress and cancellation

### 9.1 Start, then follow

Every heavy operation returns a `JobHandle` immediately:

- `engine.import.start`
- `engine.regenerate.start`
- `engine.rally.start`
- `engine.tracking.start`
- `engine.export.start`
- `library.match.import`
- `library.match.adopt`
- `library.recording.relocate`
- `library.catalog.adoptLegacy`

The client must not hold a request open for the duration of a job. Each of
these methods returns a `JobHandle` (or a result containing `jobId`)
immediately and reports progress through `job.progress`. None is subject to the
30 s lightweight request timeout after the handle is returned.

Progress notifications:

```json
{
  "jsonrpc": "2.0",
  "method": "job.progress",
  "params": {
    "jobId": "job-1",
    "matchId": "match-1",
    "state": "running",
    "stage": "proxy",
    "value": 0.42,
    "message": "encoding proxy",
    "seq": 17,
    "completedStages": ["probe", "audio"]
  }
}
```

Terminal transition:

```json
{
  "jsonrpc": "2.0",
  "method": "job.state",
  "params": {
    "jobId": "job-1",
    "matchId": "match-1",
    "state": "completed",
    "stage": "frames",
    "error": null,
    "completedStages": ["probe", "proxy", "audio", "frames"],
    "seq": 41
  }
}
```

Rules:

- `value` never decreases within one `stage`. A new stage may start at a lower
  value.
- Progress is coalesced to at most 20 notifications per second per job. The
  status method always returns the latest value, so a dropped notification is
  not a correctness failure.
- A terminal `job.state` is sent once. `engine.job.status` remains readable
  until the job is evicted from the retained set (16 finished jobs).
- `state` is one of `pending`, `running`, `completed`, `cancelled`, `failed`.
- `completedStages` comes from `checkpoints.json` for resumable jobs, exactly as
  the facade does today.

### 9.2 Cancellation

- `engine.job.cancel` flips the shared cancellation token and returns the
  current status immediately. The status may still be `running`.
- Cancellation is cooperative. The job stops at its next check and reports
  `cancelled`.
- Cancelling twice is idempotent. Cancelling a terminal job returns its
  terminal status.
- Cancelling an unknown job returns `job_not_found`.
- A cancelled job never publishes a final artifact. The manifest flip happens
  only after the output is complete, and `commit_final` keeps the existing
  synchronization.
- `service.shutdown` with `cancelRunningJobs: true` requests cancellation for
  every running job and waits up to 10 s.

### 9.3 Admission

- One heavy job at a time per service process.
- One job per match.
- Rejection is explicit, never a silent queue:
  `job_rejected` with `details.runningJobId` and a user-safe message.
- Lightweight calls are not subject to admission.

## 10. Concurrency and limits

| Limit | Value | Behavior on exceed |
| --- | --- | --- |
| Open connections | 8 | New connection refused and closed |
| In-flight requests per connection | 64 | Further requests are not read until one completes |
| Global lightweight in-flight | 256 | Backpressure; client waits |
| Heavy jobs | 1 per service, 1 per match | `job_rejected` |
| Frame size | 16 MiB | `frame_too_large`, connection closed |
| Response size | 16 MiB | `response_too_large` |
| Track window | `trackWindowDefaultSeconds` = 60, `trackWindowMaxSeconds` = 300 | `invalid_params` with a narrower-window hint |
| Handshake timeout | 5 s | Connection closed |
| Request timeout (client) | 30 s for lightweight methods only | Client times out; read methods are safe to retry. Job-starting methods are exempt once they return a handle |
| Progress notifications | 20/s per job | Coalesced |
| Idle connection | See the lifecycle state machine in [background-service.md §4.9](background-service.md#49-lifecycle-state-machine) | The idle-exit rule wins where it and the connection idle timeout both apply |
| Finished jobs retained | 16 | Oldest evicted; status returns `job_not_found`. Job-starting idempotency keys are retained by the rule in §3.1 |

Mutating methods are retried only with the same `clientRequestId`. Read methods
are safe to retry at any time. `engine.job.cancel` and `service.shutdown` are
idempotent without a key.

## 11. Worked examples

### 11.1 Probe a recording

Request:

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "engine.probe",
  "params": {
    "source": { "kind": "bookmark", "value": "Ym9va21hcms..." }
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "result": {
    "path": "/Users/ana/Movies/final.mp4",
    "durationSeconds": 1234.5,
    "frameRate": 29.97,
    "width": 1920,
    "height": 1080,
    "rotationDegrees": 0,
    "orientation": "landscape",
    "hasAudio": true,
    "sizeBytes": 987654321
  }
}
```

### 11.2 Import a recording (custody)

Request:

```json
{
  "jsonrpc": "2.0",
  "id": 11,
  "method": "library.match.import",
  "clientRequestId": "0f6b0f3e-6f7a-4f3e-9f0e-2d1c4b5a6978",
  "params": {
    "source": { "kind": "bookmark", "value": "Ym9va21hcms..." },
    "title": "Final vs Northside",
    "workspaceId": "workspace-1"
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 11,
  "result": {
    "importId": "import-1",
    "matchId": "match-1",
    "jobId": "job-1"
  }
}
```

Progress:

```json
{
  "jsonrpc": "2.0",
  "method": "job.progress",
  "params": {
    "jobId": "job-1",
    "matchId": "match-1",
    "state": "running",
    "stage": "copy",
    "value": 0.37,
    "message": "copied 365 of 987 MB",
    "seq": 9,
    "completedStages": ["probe"]
  }
}
```

After completion, read the match:

```json
{ "jsonrpc": "2.0", "id": 12, "method": "library.match.get", "params": { "matchId": "match-1" } }
```

### 11.3 Start artifacts and follow progress

```json
{
  "jsonrpc": "2.0",
  "id": 13,
  "method": "engine.import.start",
  "params": { "matchId": "match-1", "samplingRate": 2.0 }
}
```

```json
{ "jsonrpc": "2.0", "id": 13, "result": { "jobId": "job-2", "matchId": "match-1" } }
```

Then either wait for `job.state` or poll:

```json
{ "jsonrpc": "2.0", "id": 14, "method": "engine.job.status", "params": { "jobId": "job-2" } }
```

### 11.4 Cancel

```json
{ "jsonrpc": "2.0", "id": 15, "method": "engine.job.cancel", "params": { "jobId": "job-2" } }
```

```json
{
  "jsonrpc": "2.0",
  "id": 15,
  "result": {
    "jobId": "job-2",
    "matchId": "match-1",
    "state": "cancelled",
    "stage": "proxy",
    "progress": { "stage": "proxy", "value": 0.62, "message": null },
    "error": null,
    "completedStages": ["probe"]
  }
}
```

### 11.5 Catalog mutation and notification

```json
{
  "jsonrpc": "2.0",
  "id": 16,
  "method": "library.rally.save",
  "params": {
    "rally": {
      "id": "rally-1",
      "matchId": "match-1",
      "startSeconds": 41.2,
      "endSeconds": 63.8,
      "winnerSide": "left",
      "status": "confirmed",
      "confidence": null,
      "highlightScore": null
    }
  }
}
```

```json
{
  "jsonrpc": "2.0",
  "method": "catalog.changed",
  "params": {
    "entities": ["rally", "score"],
    "matchId": "match-1",
    "workspaceId": "workspace-1",
    "revision": 1042
  }
}
```

### 11.6 Error

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "method": "engine.start.doesNotExist",
  "params": {}
}
```

```json
{
  "jsonrpc": "2.0",
  "id": 17,
  "error": {
    "code": -32601,
    "message": "unknown method engine.start.doesNotExist",
    "data": {
      "kind": "method_not_found",
      "retryable": false,
      "userMessage": "This version of Sportcut and its analysis service do not match. Reinstall the app."
    }
  }
}
```

### 11.7 Shutdown

```json
{
  "jsonrpc": "2.0",
  "id": 18,
  "method": "service.shutdown",
  "params": { "cancelRunningJobs": true, "reason": "app quit" }
}
```

```json
{ "jsonrpc": "2.0", "id": 18, "result": { "accepted": true } }
```

```json
{
  "jsonrpc": "2.0",
  "method": "service.shutdown",
  "params": { "reason": "app quit", "deadlineMs": 10000 }
}
```

## 12. Compatibility rules

- **Major version** covers breaking changes: removing or renaming a method,
  field, or enum value; changing a type; changing framing. A client and service
  with different majors do not connect.
- **Minor version** covers additive changes: new methods, new optional fields,
  new enum values, new capabilities, new error kinds in the documented range.
- **Enums are append-only.** A client that sees an unknown enum value must
  treat it as the documented fallback (for example `unknown`) rather than crash.
- **Required fields are never removed or retyped** within a major. New required
  fields require a new major or a new method.
- **Unknown methods** return `method_not_found`; unknown fields are ignored.
- **Deprecation:** a method may be marked deprecated in a minor, but it keeps
  working for the life of the major. Both sides log a deprecation warning.
- **Capabilities:** a method is callable only when its capability is in the
  negotiated intersection. The tables above name the capability groups
  (`engine.v1`, `catalog.v1`, `custody.v1`, `notifications.v1`,
  `idempotency.v1`, `playback.path.v1`, `metrics.v1`, `diagnostics.v1`).
- **Catalog schema is independent.** Protocol 1.x works with catalog schema 6.
  A future catalog schema is negotiated through `service.hello` and
  `library.catalog.status`; the service runs migrations before readiness.
- **Artifact schemas are independent** and keep their existing versions:
  manifest 3, checkpoint 1, calibration 1, tracks 1, rally suggestions 1.
- **Bundled versioning.** In v1 the app and service ship together. The service
  version must be the app version plus a build identifier. A version mismatch
  inside one bundle is a release error.
