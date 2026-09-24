## Context

Video import already exists as a thin path: `VideoFilePicker` wraps
`file_picker`, `MatchRepository.importVideo` probes the picked path through the
bridge and writes a `MatchRecord` whose `videoPath` **is** the picked path, and
`LibraryScreen` drives it from an import button. `MatchCatalog` owns a versioned
migration framework, and `MatchPaths` resolves the app documents directory for
the engine's per-match artifact directories.

What that path gets wrong is where the bytes live after import. On both mobile
platforms the picker hands back a copy it made itself, in a directory the
operating system is allowed to empty:

| Platform | Path the picker returns | Evidence |
| --- | --- | --- |
| iOS | `NSTemporaryDirectory()/<uuid>/<name>` | `file_picker_darwin` 2.1.2, `IOSFilePickerHandler.copyToTemporaryDirectory`, used by both the `PHPickerViewController` (photo library) and `UIDocumentPickerViewController` paths |
| Android | `cacheDir/file_picker/<timestamp>/<name>` | `android_file_picker` 2.0.0, `FileUtils.loadFiles` writes content-URI results into the app cache |

So `MatchRecord.videoPath` currently points at a file the OS may delete between
two launches, while the match-library spec promises the recording is "referenced
in place". Those two statements cannot both hold, and the pipeline stages that
come next all read the recording: probe, proxy, frames, playback, and eventually
export.

Two constraints bound the fix:

- The engine owns artifact files inside each match directory, with a documented
  layout (`manifest.json`, `checkpoints.json`, and the `proxy/`, `audio/`,
  `frames/`, `calibration/`, `tracks/` subdirectories). The app owns the SQLite
  catalog. Neither side should start writing into the other's space.
- The repository's guardrail is that the user's recording is never copied,
  moved, or modified. That guardrail exists to protect the user's file, and this
  change must keep protecting it — the copy it introduces is of the platform's
  transient hand-off, not a second copy of a file the user still owns in place.

## Goals / Non-Goals

**Goals:**

- A match created today is still playable and analyzable after a restart, an OS
  purge of temp and cache directories, and a low-storage cleanup.
- The user's selected file is untouched: same bytes, same location, same name,
  still under the user's control.
- Import is a legible operation: one at a time, visible while it runs,
  cancellable, and with a specific message for each way it can fail.
- No partial state ever: no catalog record without a readable recording, no
  orphaned copy without a record, no half-written file presented as a recording.
- The engine stays untouched, and the app's storage layout stays separable from
  the engine's.

**Non-Goals:**

- Analysis: generating proxy, audio, and frames on import stays a separate,
  user-triggered action owned by the media-pipeline capability.
- Court calibration, tracking, rally detection, scoring, highlights, export.
- Playback improvements beyond reporting an unavailable recording honestly.
- De-duplicating recordings a user imports twice under different titles.
- Reaching the user's photo library for anything other than picking one video.

## Decisions

### D1. Import takes custody; the app-owned copy is the match's recording

`importVideo` copies the picked file once into an app-owned recordings root and
stores that path as the match's recording. The picked path is an input to the
copy, never a stored value.

Alternatives considered:

- *Keep referencing the picked path in place.* Rejected — on iOS and Android
  that path is a purgeable copy, so it breaks exactly the promise the spec
  makes. It also cannot work at all for a photo-library asset, whose "in place"
  location is not a path at all.
- *Write the copy inside the engine's match directory.* Rejected — that
  directory is the engine's, its layout is documented and stable, and its
  contents are treated as derived artifacts: the "delete analysis files" action
  deletes the directory recursively, which would take the recording with it.
- *Have the engine take custody.* Rejected — the engine's job is reading local
  media, not owning user files, and this would put an OS-specific copy policy
  behind the language boundary.

```
Documents/
  SportcutRecordings/<matchId>/<sanitized name>   <- app-owned custody (new)
  SportcutMatches/<matchId>/                      <- engine artifacts (unchanged)
      manifest.json  checkpoints.json  proxy/  audio/  frames/  calibration/  tracks/
```

The guardrail changes wording, not intent: the user's file is still never
copied, moved, or modified — the bytes that get copied are the platform's
temporary hand-off. `AGENTS.md` and `docs/plans/README.md` are updated in the
same change so the agreement does not contradict the code.

### D2. Custody is one small component with a narrow contract

A `RecordingStore` copies a `PickedVideo` into `<root>/<matchId>/<name>` and
returns the destination path; a `remove` deletes that directory. It is
constructed from the recordings root, so tests exercise it against a temp
directory with no platform involvement.

Details that make it safe:

- **Streamed copy**, never `readAsBytes`, so a 4 GB recording does not have to
  fit in memory.
- **Copy to `part` then rename**, so an interrupted copy can never be mistaken
  for a complete recording.
- **Sanitized file name**, derived from the picker's display name, with the
  match id as the directory so two recordings with the same name cannot collide.
- **Out-of-space recognized from the failed write**, so a full device is
  reported as an out-of-space problem rather than as a generic storage failure,
  and the partial file is removed. Dart exposes no portable free-space query and
  this change adds no dependency, so the shortage is detected when the write
  fails rather than before the copy starts.
- **Cleanup on failure**, so a copy that cannot finish leaves no directory.

Order of operations in `importVideo` becomes: ensure the picked file is readable
→ probe it (reject unsupported media before copying gigabytes) → take custody →
insert the catalog record. If the insert fails, the custodied copy is removed, so
a failed import leaves nothing behind.

### D3. The catalog records where the recording came from

Schema version 2 adds two nullable columns to `matches`:

| Column | Meaning |
| --- | --- |
| `original_path` | The path the picker returned, kept for support and diagnostics. Not read from to play or analyze. |
| `source_bytes` | Size of the app-owned copy, so the library can show what a match costs in storage. |

ADD-only migration through the existing `Migration` list, so an install at
version 1 replays it and keeps every match. Rows migrated from version 1 keep
their existing `video_path`; if that path has already been purged, the library
now reports the match as unavailable instead of failing later (D5).

### D4. Import state is owned by one Riverpod notifier, and it is single-flight

`LibraryScreen` currently calls the picker, the repository, and
`ref.invalidate` inline, with no state and no re-entrancy guard: two taps open
two pickers. Import moves behind an `ImportController` (a Riverpod notifier)
exposing `idle | picking | importing` plus the last problem. The copy and the
metadata probe run inside one repository call, so the controller reports them as
the single in-flight step they are rather than inventing a phase boundary it
cannot observe.

- The guard is checked *before* the picker opens, so it covers the dialog as
  well as the copy; the guard lives in the notifier rather than the repository
  because the repository never sees a second dialog opened.
- The screen renders an in-progress import as a labelled progress bar with a
  cancel action, and disables the import affordances while it runs.
- Cancellation is a flag the copy loop checks between chunks; cancelling deletes
  the partial copy and writes no record.
- On success the notifier invalidates `matchListProvider`; nothing else in the
  library changes.

Alternative considered: a boolean `isImporting` in the widget's `State`.
Rejected — it disappears with the widget, cannot be exercised without pumping a
widget, and does not survive a rebuild triggered by list invalidation.

### D5. Failures are classified, not string-matched

`MatchImportException` gains a `kind` (`cancelled`, `unreadable`, `unsupported`,
`noSpace`, `storage`, `catalog`, `pickerFailed`) while keeping its
user-facing message. The repository maps engine and filesystem errors onto those
kinds; the screen maps the picker's `PlatformException` onto `pickerFailed`
instead of letting it escape as an unhandled async error, which is what happens
today.

Screens show `exception.message`; the kind exists so behavior that must differ
(cancellation is silent, failure is not) does not depend on parsing prose.

### D6. Availability is checked cheaply, at list time

The library marks a match unavailable when its stored recording is missing or
cannot be opened, using a filesystem check — no engine call, no probe. The match
stays listed, `Play` reports the reason explicitly, and the row shows an
unavailable marker. This is what turns "the OS purged our file" from a silent
failure into a legible one, and it also covers a user deleting the app-owned
copy or restoring a backup without it.

### D7. Deleting a match offers the app-owned copy too

The delete dialog currently asks only whether to delete derived artifacts. It
gains a second, separately-labelled choice for the app-owned recording copy, and
the copy is removed only when asked. The user's original file is never a
candidate for deletion and the dialog says so.

### D8. Platform configuration is declared and confirmed

- iOS: add `NSPhotoLibraryUsageDescription` to `Runner/Info.plist`, so the
  photo-library path has a declared purpose.
- Android: no runtime permission is needed — `android_file_picker` 2.0.0 asks
  for `video/*` with `Intent.ACTION_GET_CONTENT`, a Storage Access Framework
  picker that grants read access to the chosen file, and the plugin manifest
  declares no `uses-permission`. That was confirmed against the installed
  plugin and is recorded in `video_file_picker.dart` and the verification
  record, rather than assumed, so nobody adds a permission the app does not use.
  The same reading shows why custody is required: the plugin copies the chosen
  content URI into the app cache, and the URI grant does not outlive the
  process.
- Both iOS entry points (photo library and document picker) already return
  through the same `PickedVideo`, so the custody path is shared.
- The `macOS` runner keeps working for development, and it needs one thing of
  its own: `file_picker`'s macOS implementation refuses to open `NSOpenPanel`
  unless the app is signed with `com.apple.security.files.user-selected.read-only`
  (or read-write). It reads that entitlement off the running task, so the check
  fails on an *unsandboxed* development build too. Both `DebugProfile` and
  `Release` entitlements therefore carry it, and the same custody path runs on
  macOS against the documents directory.

## Risks / Trade-offs

- **Storage doubles for the user's own recordings.** Importing a recording that
  already lives in app storage copies it again. → Accepted for this change: the
  alternative is a match that silently breaks. The library shows what each match
  costs (`source_bytes`), and deletion can reclaim it.
- **A multi-gigabyte copy takes time and can be interrupted.** → Streamed copy,
  `part`-then-rename, visible progress, cancellation, and a free-space check
  before the copy starts.
- **Downgrading the app leaves a version-2 database** that a version-1 build
  cannot open. → Acceptable pre-release; the migration is additive, so a
  downgrade handler that drops the two columns is a small future change.
- **Existing matches keep whatever path they were stored with.** If that path
  was already purged, the match is reported unavailable rather than repaired.
  → The honest failure is preferable, and re-importing the recording is a
  working remedy. No back-fill is attempted.
- **The guardrail wording in `AGENTS.md` changes.** → The change updates the
  guardrail in the same commit as the code, and keeps its substance: the user's
  original file is never written to.
- **A recording could be imported twice.** → Out of scope; no content hashing
  and no de-duplication in this change.

## Migration Plan

1. Ship the schema version 2 migration with the code; existing installs upgrade
   in place on next launch, keeping their matches.
2. Existing matches keep their current recording path. Their availability is
   now reported honestly in the library.
3. No engine, bridge, or artifact-layout change ships with this, so the engine
   track is unaffected.
4. Rollback means reinstalling the previous build or adding a downgrade handler;
   no user data is deleted by the migration itself.

## Open Questions

- Should a very large import (for example a 60-minute 4K recording) warn before
  copying, or copy and report progress? Current design copies and reports
  progress with a free-space check; a size threshold can be added later.
- Should the recording copy live under the documents directory (backed up, and
  restorable) or the application-support directory (excluded from backup)? The
  documents directory is chosen here for consistency with the artifact root; it
  is worth revisiting once backup size becomes a real complaint.
