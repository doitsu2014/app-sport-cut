# Video import verification

Evidence for the `add-video-import` change, gathered with Flutter 3.47.5 /
Dart 3.13.4 on macOS (`SPORTCUT_FLUTTER_BIN=/path/to/flutter/bin`).

## What this change had to fix

Import already existed, but it stored the path the platform picker returned. On
both mobile platforms that path is a copy the operating system may delete:

| Platform | Where the picked file lives | Evidence |
| --- | --- | --- |
| iOS | `NSTemporaryDirectory()/<uuid>/<name>` | `file_picker_darwin` 2.1.2 `IOSFilePickerHandler.copyToTemporaryDirectory`, used by both the `PHPickerViewController` (photo library) and `UIDocumentPickerViewController` paths |
| Android | `cacheDir/file_picker/<timestamp>/<name>` | `android_file_picker` 2.0.0 `FileUtils.loadFiles` writes content-URI results into the app cache |

The Android picker requests `video/*` with `Intent.ACTION_GET_CONTENT`
(`FileUtils.startFileExplorer`), a Storage Access Framework picker. The plugin
manifest declares no `uses-permission`, so no runtime media permission is
needed — and because the URI grant does not outlive the process, the cached copy
is the only durable artifact the app has from the pick. That is precisely why
custody has to happen at import.

## Commands

```bash
cd app && flutter analyze
```

```text
Analyzing app...
No issues found! (ran in 0.8s)
```

```bash
cd app && flutter test
```

```text
00:01 +52: All tests passed!
```

52 tests pass, across `bridge_test`, `match_catalog_test`,
`match_repository_test`, `library_screen_test`, `player_screen_test`,
`formatters_test`, and `app_shell_test`. No new dependency was introduced:
`app/pubspec.yaml` and `app/pubspec.lock` are unchanged, and every package this
change uses (`file_picker`, `path`, `path_provider`, `sqflite`,
`flutter_riverpod`) already has a row in `docs/legal/dependency-register.md`.

## Scenario to test mapping

### `match-library` — Match creation and local video import (modified)

| Scenario | Test |
| --- | --- |
| Import creates a match record | `import takes custody of the picked recording` |
| Original recording left untouched | `import takes custody of the picked recording`, `deleting a match keeps what it owns unless asked to remove it` |
| Imported recording survives an operating-system purge | `the app-owned copy outlives the file the picker returned` |
| Transient picker path is not stored as the recording | `import takes custody of the picked recording` |
| Import cannot access the file | `a missing file is reported and leaves no catalog record`, `a file that cannot be opened is reported as an access problem` |

### `match-library` — Match library browsing (modified)

| Scenario | Test |
| --- | --- |
| Matches listed | `matches are listed with title, duration, and creation date` |
| Imported media metadata shown | `matches are listed with title, duration, and creation date`, `media summaries name what is known and skip what is not` |
| Unavailable recording reported | `a match whose recording has gone is listed as unavailable`, `a match whose recording has gone is reported unavailable` |
| Empty library | `an empty library offers to import a recording` |

### `match-library` — Local catalog ownership and schema (modified)

| Scenario | Test |
| --- | --- |
| Schema changes are versioned | `a schema change is applied as a migration and existing matches survive`, `a match written before the recording origin was stored still loads` |
| Catalog works offline | Unchanged by this change; SQLite access is local (`sqflite`), and no network call was added anywhere in the import path |
| Match deletion | `deleting a match keeps what it owns unless asked to remove it`, `deleting a match asks about the derived artifacts`, `the stored recording copy can be deleted with the match` |

### `match-library` — Import progress and single-flight (added)

| Scenario | Test |
| --- | --- |
| Import in progress is visible | `an import in progress is visible and cannot be started twice` |
| Second import attempt is not started | `an import in progress is visible and cannot be started twice` |
| Cancelled import leaves nothing behind | `a cancelled import leaves neither a match nor a partial copy`, `a cancelled import is silent and stores nothing` |

### `match-library` — Import failure reporting (added)

| Scenario | Test |
| --- | --- |
| Unsupported recording reported | `an unreadable codec is reported and leaves no copy behind`, `an unreadable recording is reported and nothing is stored` |
| Insufficient storage reported | `a write that fails on a full device is classified as out of space`, `a copy that cannot be written is reported and leaves nothing behind` |
| Picker failure reported | `a picker failure is reported rather than thrown` |

## Migration evidence

`MatchCatalog.schemaVersion` is now 2, and the version-2 migration adds the
nullable `original_path` and `source_bytes` columns and nothing else. Both
directions are covered:

- a catalog written by version 1 opens at version 2 with its match intact and
  the two new columns present, loading the old row with a null origin and size
  (`a match written before the recording origin was stored still loads`);
- a match round-trips its origin and size through insert and list
  (`a match records where its recording came from and what it costs`).

## Two implementation notes recorded back into the artifacts

- **Out-of-space is detected from the failed write, not before the copy.**
  Dart exposes no portable free-space query, and this change adds no dependency,
  so `RecordingStore` recognizes `ENOSPC`/`ERROR_DISK_FULL` from the write error
  and reports it as an out-of-space problem, removing the partial file. The
  `tasks.md` and `design.md` wording was corrected to match.
- **Import reports one in-flight phase, not a copy phase and a probe phase.**
  The repository performs the probe and the copy inside a single call, so
  `ImportState` exposes `idle | picking | importing` rather than a boundary the
  controller cannot observe. `tasks.md` and `design.md` were corrected to match.

## Platform configuration

### macOS: the picker needs a file-access entitlement

Running the developer runner and pressing **Import video** reported:

```text
The video picker could not open: Either the Read-Only or Read-Write
entitlement is required for this action.
```

That message is this change working — the picker's `PlatformException` is now
reported instead of escaping as an unhandled async error (before this change it
was an unhandled error with nothing shown to the user).

The cause is `file_picker`'s macOS implementation
(`MacOSFilePickerHandler.checkEntitlement`), which reads
`com.apple.security.files.user-selected.read-only` (or read-write) off the
running task with `SecTaskCopyValueForEntitlement` and refuses to open
`NSOpenPanel` without it. It checks the entitlement rather than the sandbox, so
an *unsandboxed* development build needs it too. The built app was signed
without it:

```text
com.apple.security.app-sandbox      = False
com.apple.security.cs.allow-jit     = True
com.apple.security.get-task-allow   = True
com.apple.security.network.server   = True
```

Both `app/macos/Runner/DebugProfile.entitlements` and `Release.entitlements` now
declare `com.apple.security.files.user-selected.read-only` — read-only is
sufficient, because the picked file is read and copied into app-owned storage
and never modified. After rebuilding:

```bash
cd app && flutter build macos --debug
codesign -d --entitlements :- build/macos/Build/Products/Debug/sportcut.app
```

```text
com.apple.security.app-sandbox                       = False
com.apple.security.cs.allow-jit                      = True
com.apple.security.files.user-selected.read-only     = True
com.apple.security.get-task-allow                    = True
com.apple.security.network.server                    = True
```

The entitlement is part of the code signature, so it is picked up by a fresh
build; a hot reload or hot restart of an already-running app does not re-sign
it.

### iOS: the build carries the purpose string

```bash
cd app && flutter build ios --debug --no-codesign
```

```text
Xcode build done.   76.3s
✓ Built build/ios/iphoneos/Runner.app
```

The built bundle carries the declaration:

```text
$ PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" \
    build/ios/iphoneos/Runner.app/Info.plist
Sportcut imports a badminton recording you choose from your photo library.
Everything stays on this device.
```

## Not verified here

- Choosing a recording out of the iOS photo library on a device or simulator.
  The build and the declaration are verified; the picker itself is an
  interactive system sheet and was not driven.
- The Android picker on an emulator or device. `flutter doctor` reports no
  Android SDK on this machine, so no Android build was produced.
- The end-to-end flow with a real recording through the native engine and
  `video_player`, which the bootstrap change also records as outstanding
  (`docs/verification/client-track.md`, tasks 7.5 and 9.2).

Note on the toolchain: `docs/verification/client-track.md` recorded that no full
Xcode installation was present. That is no longer true — `flutter doctor`
reports Flutter 3.47.5 with Xcode 26.6 and one connected device, and both the
macOS and the iOS builds above succeeded on this machine. The Android SDK is
still absent.

`docs/verification/client-track.md` describes the pre-existing behaviour as
"import references the recording in place". That was accurate when it was
written and is superseded by this change: the match now records an app-owned
copy.
