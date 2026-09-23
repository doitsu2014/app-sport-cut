## Why

The product's first user-facing capability — turning a recording on the user's
phone into a match in the library — is only half built. The bootstrap shipped an
import path that stores whatever path the platform picker returned, and on both
mobile platforms that path is a *transient* copy: iOS `file_picker` copies a
picked asset into `NSTemporaryDirectory()`, and Android materializes content
URIs under `cacheDir/file_picker/`. The operating system is free to purge both.
A match created today can therefore be unplayable tomorrow, and every later
stage — calibration, analysis, highlights, export — reads the recording, so
nothing built on top of import can be trusted until import owns its source file.

## What Changes

- Import takes **durable custody** of the selected recording: the file is copied
  once into app-owned storage for that match, and the catalog records that
  app-owned copy as the match's recording. The user's original file is never
  modified, moved, renamed, or deleted.
- The path the platform picker returns is treated as *input to custody*, never
  as the stored recording path, so an operating-system purge of temporary or
  cache directories cannot break a match that was already imported.
- Import becomes a visible, single-flight operation: one import at a time, a
  progress state while the copy and metadata probe run, and a cancel that leaves
  the library exactly as it was.
- Every import failure mode gets its own user-facing message — cancellation,
  access denied, file gone, unsupported container, insufficient storage, picker
  failure — and each one leaves no catalog record, no partial copy, and no
  temporary leftovers behind.
- Media metadata read during import (duration, resolution, frame rate, audio
  presence) is surfaced with the match, and a match whose stored recording has
  become unreadable is reported as unavailable instead of failing silently.
- The catalog gains a migration so a stored match can record where its recording
  came from and how much space its app-owned copy uses.

No **BREAKING** changes: there is no public release, and the catalog migrates
forward in place rather than restructuring the `matches` table, so an existing
install keeps its matches.

## Capabilities

### New Capabilities

None. Import is already named in the `match-library` capability; this change
finishes its behavior rather than introducing a new contract.

### Modified Capabilities

- `match-library`: the import requirement changes from "reference the original in
  place" to durable app-owned custody that leaves the user's original untouched;
  import gains progress, single-flight, cancellation, and per-failure reporting;
  browsing surfaces the imported metadata and reports an unavailable recording;
  deletion offers the app-owned recording copy for removal.

## Impact

- **Client code**: `app/lib/src/features/library/` — the picker adapter, a new
  custodian that copies a picked file into app-owned storage, `MatchRepository`,
  `MatchRecord`, `MatchPaths`, the library providers, and the library screen's
  import flow.
- **Catalog**: a versioned migration adding the recorded-origin and size columns
  to `matches`, using the migration framework already in `MatchCatalog`.
- **Storage layout**: a new app-owned recordings root next to (not inside) the
  engine's per-match artifact directory, so the engine's documented artifact
  layout (`manifest.json`, `checkpoints.json`, `proxy/`, `audio/`, `frames/`,
  `calibration/`, `tracks/`) is unchanged.
- **Platform configuration**: the iOS photo-library purpose string and the
  picker entry points are declared and confirmed per platform.
- **Engine**: no change. The Rust facade, DTOs, and artifact layout are untouched;
  the engine is handed the path of the app-owned copy like any other local file.
- **Data at risk**: the app now stores a copy of each imported recording, so
  deletion and free-space behavior have to be explicit. Files the user selected
  remain under the user's control and are never written to.
