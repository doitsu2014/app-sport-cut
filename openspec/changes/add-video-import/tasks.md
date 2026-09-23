## 1. Custody of the picked recording

- [x] 1.1 Add a recordings root to `MatchPaths` (`Document/SportcutRecordings/<matchId>`) alongside the existing artifact root, keeping the two directories separate so the engine's match-directory layout is untouched
- [x] 1.2 Implement `RecordingStore`: a streamed copy into the match's recording directory, written to a `.part` file and renamed into place, using a sanitized name derived from the picker's display name
- [x] 1.3 Give `RecordingStore` an out-of-space detection that reports a full device as such rather than as a generic write failure, a `remove(matchId)` that deletes the recording directory, and cleanup that leaves no directory behind when a copy fails or is cancelled
- [x] 1.4 Extend `MatchRecord` with `originalPath` and `sourceBytes`, including `copyWith`, so the catalog can record where a recording came from and what it costs
- [x] 1.5 Rework `MatchRepository.importVideo` to the order readable → probe → take custody → insert, storing the app-owned copy as `videoPath`, and removing the copy if the catalog insert fails

## 2. Catalog schema

- [x] 2.1 Add a schema version 2 migration to `MatchCatalog` adding the nullable `original_path` and `source_bytes` columns to `matches`, and update the row mapping in both directions
- [x] 2.2 Confirm an install at version 1 migrates in place and keeps every match, and that a version-1 row still loads with a null origin and size

## 3. Import failure reporting

- [x] 3.1 Add a failure `kind` to `MatchImportException` (`cancelled`, `unreadable`, `unsupported`, `noSpace`, `storage`, `catalog`, `pickerFailed`) while keeping the user-facing message
- [x] 3.2 Map engine probe failures, unreadable input, insufficient storage, and copy or catalog write failures onto those kinds in `MatchRepository`, so a full disk is reported as such rather than as a generic write error
- [x] 3.3 Treat a `PlatformException` from the picker as `pickerFailed` and present it as a message instead of letting it escape as an unhandled error
- [x] 3.4 Ensure cancellation produces no message, no catalog record, and no leftover copy

## 4. Import state and the library screen

- [x] 4.1 Add an `ImportController` Riverpod notifier exposing `idle`, `picking`, and `importing` plus the last problem, with the single-flight guard checked before the picker opens and a cancel that aborts an in-flight import
- [x] 4.2 Drive `LibraryScreen` from the controller: show that an import is in progress, disable the import affordances while one runs, and keep the empty state's import action working
- [x] 4.3 Show the imported media metadata (resolution, frame rate, audio presence) and the app-owned copy's size with each match in the library list

## 5. Unavailable recordings and deletion

- [x] 5.1 Add a cheap list-time availability check on each match's stored recording and mark the match unavailable when it cannot be opened, without hiding or removing it
- [x] 5.2 Make `Play` report the reason explicitly when a match's recording is unavailable, instead of opening playback onto a missing file
- [x] 5.3 Extend the delete dialog with a separately-labelled choice for the app-owned recording copy, remove it through `RecordingStore` only when chosen, and state that the file the user originally selected is never deleted

## 6. Platform configuration

- [x] 6.1 Declare the iOS photo-library purpose string in `app/ios/Runner/Info.plist` for the picker's photo-library path
- [x] 6.2 Record that the Android picker requests `video/*` with `ACTION_GET_CONTENT` (a Storage Access Framework picker, so no runtime media permission is needed), and confirm both iOS entry points (photo library and document picker) return through the same `PickedVideo` and custody path
- [x] 6.3 Sign the macOS runner with the user-selected file entitlement its picker requires, in both the development and release entitlement files, and confirm it is embedded in the built application

## 7. Documentation and verification

- [x] 7.1 Update the recording guardrail in `AGENTS.md` and the match-library milestone text in `docs/plans/README.md` so both describe taking custody of the picked file while leaving the user's original untouched
- [x] 7.2 Confirm no new third-party dependency was introduced, and that `docs/legal/dependency-register.md` therefore needs no new row
- [x] 7.3 Update the existing repository and library-screen tests that assert the old reference-in-place behavior
- [x] 7.4 Run `flutter analyze` in `app/` and confirm it is clean
- [x] 7.5 Run the change verification workflow and record the evidence under `docs/verification/`
