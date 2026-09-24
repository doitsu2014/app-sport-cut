# Verification record

Evidence gathered while implementing this change. The detail lives in
[`docs/verification/video-import.md`](../../../docs/verification/video-import.md).

## Client verification commands

```bash
cd app && flutter analyze   # No issues found!
cd app && flutter test      # 00:01 +52: All tests passed!
```

Flutter 3.47.5 / Dart 3.13.4, macOS.

## Task coverage

| Task | Evidence |
| --- | --- |
| 1.1–1.5 | `test/match_repository_test.dart` — custody, copy location, purge survival, cancellation cleanup, catalog rollback |
| 2.1–2.2 | `test/match_catalog_test.dart` — version-2 migration adds the columns, a version-1 row still loads with null origin and size, origin and size round-trip |
| 3.1–3.4 | `test/match_repository_test.dart` and `test/library_screen_test.dart` — failure kinds, storage and out-of-space classification, picker failure as a message, silent cancellation |
| 4.1–4.3 | `test/library_screen_test.dart` — in-progress state, single-flight, disabled affordances, media metadata in the list |
| 5.1–5.3 | `test/library_screen_test.dart` and `test/match_repository_test.dart` — availability marking, playback refusal, separate recording-deletion choice |
| 6.1–6.2 | `app/ios/Runner/Info.plist` purpose string; the Android `ACTION_GET_CONTENT`/no-permission finding is recorded in `video_file_picker.dart`, `design.md` D8, and the verification detail |
| 6.3 | `com.apple.security.files.user-selected.read-only` added to `DebugProfile.entitlements` and `Release.entitlements`, rebuilt with `flutter build macos --debug`, and confirmed in the signed binary with `codesign -d --entitlements` |
| 7.1 | `AGENTS.md` guardrail and `docs/plans/README.md` both describe custody |
| 7.2 | No dependency changed: `app/pubspec.yaml` and `app/pubspec.lock` are untouched |
| 7.3–7.4 | Framework tests updated for custody; `flutter analyze` clean |
| 7.5 | This record and `docs/verification/video-import.md` |

## Not verified

- 6.1 runtime: picking out of the iOS photo library on a device. The iOS build
  and the purpose string inside the built bundle are verified
  (`flutter build ios --debug --no-codesign`), but the picker is an interactive
  system sheet and was not driven.
- 6.2 runtime: the Android picker on an emulator or device. `flutter doctor`
  reports no Android SDK on this machine, so no Android build was produced.

The toolchain moved since the bootstrap change was verified:
`docs/verification/client-track.md` recorded no full Xcode installation, and
Flutter 3.47.5 with Xcode 26.6 is now present, so the macOS and iOS builds run
here. The engine-side and device-flow gaps the bootstrap change records as
tasks 7.5 and 9.2 are unchanged.
