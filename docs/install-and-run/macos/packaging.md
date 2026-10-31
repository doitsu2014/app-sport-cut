# macOS — production packaging and install (DMG)

This is the deployment path for installing Sportcut on a Mac: build a release
bundle with the background service, model, and TFLite runtime embedded, sign it,
and write a DMG.

It produces a **personal build**, not a distributable release. The limitations
are listed at the end; the architecture behind the helper is in
[background-service.md §9](../../architecture/background-service.md#9-sandbox-packaging-signing-and-notarization).

## 1. Before you package

```bash
tools/preflight.sh --profile macos
```

Required:

- Xcode (a full installation, not Command Line Tools).
- Rust 1.80+ with `cargo`.
- Flutter with Dart 3.
- `ffmpeg` and `ffprobe` installed on the Mac. They are **runtime**
  requirements: the packaged app does not bundle them.
- Inference assets in `third_party/inference/`
  (`libtensorflowlite_c.dylib`, `model.tflite`). Fetch them with
  `tools/fetch-inference-assets.sh`; without them the build still works but
  player tracking is unavailable.

If Flutter is not on `PATH`, set `SPORTCUT_FLUTTER_BIN` to the directory that
contains the `flutter` executable.

## 2. Build the DMG

```bash
tools/package-macos.sh
# → dist/Sportcut.dmg
```

The script runs these steps:

1. `tools/build-service.sh` — release `sportcut-service`, with
   `macos-tflite-eval` enabled by default on macOS.
2. `flutter build macos --release` — the client bundle.
3. `tools/embed-service.sh` — the helper at
   `Contents/Helpers/SportcutService`.
4. `tools/embed-inference-assets.sh` — the runtime at
   `Contents/Frameworks/libtensorflowlite_c.dylib`, the model at
   `Contents/Resources/model.tflite`.
5. Codesign, then `hdiutil` to write `dist/Sportcut.dmg`.

`dist/` is build output and is git-ignored.

### Signing

By default the build is **ad-hoc signed**:

```bash
tools/package-macos.sh
```

The app carries `app/macos/Runner/Release.entitlements` (file-picker access; the
sandbox is off for this personal build), the helper and inference dylib are
signed, then the outer app is signed. Ad-hoc signing deliberately omits the
hardened runtime so the helper can load the ad-hoc dylib.

With a Developer ID identity, all three are signed with a real identity:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  tools/package-macos.sh
```

That is a prerequisite for notarisation, but notarisation is not implemented in
this build.

### If the release build fails on Xcode modules

A stale module cache can produce errors such as:

```
Could not build module 'Darwin'
cannot open .../MacOSX27.0.sdk/usr/include/mach/exception.h
```

The SDK symlink may have moved (for example 27.0 → 27.2) while the cache still
names the old path. Clear the shared caches and rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/{ModuleCache.noindex,CompilationCache.noindex,Runner-*}
cd app && flutter clean && flutter build macos --release
```

The debug build is unaffected because it can reuse already-compiled pods.

## 3. Install

1. Open `dist/Sportcut.dmg`.
2. Drag `sportcut.app` to **Applications**.
3. First launch: right-click the app → **Open**. The build is ad-hoc signed, so
   Gatekeeper will not accept a double-click the first time.

## 4. What the installed app does

On launch, if neither `SPORTCUT_ENDPOINT` nor `SPORTCUT_STATE_ROOT` is set, the
app starts the embedded helper itself
(`app/lib/src/bridge/service_supervisor.dart`):

```
Contents/Helpers/SportcutService
  --state-root  ~/Library/Application Support/com.sportcut.sportcut/state
  --endpoint    …/state/run/s.sock
  --token-file  …/state/run/token
  --ffmpeg      /opt/homebrew/bin/ffmpeg      (or /usr/local/bin, then PATH)
  --ffprobe     /opt/homebrew/bin/ffprobe
  --tflite-library Contents/Frameworks/libtensorflowlite_c.dylib
  --person-model   Contents/Resources/model.tflite
```

A running helper is reused on the next launch; a normal quit asks it to stop.
The helper also has a hard 20-second start deadline and reports failure with the
log path.

### Data layout

| Path | Contents |
| --- | --- |
| `~/Library/Application Support/com.sportcut.sportcut/state/matches/<id>/` | manifest, checkpoints, proxy, audio, frames, calibration, tracks, export |
| `…/state/recordings/<id>/` | the service-readable copy of the recording |
| `…/state/inbox/` | hand-off staging for probe and import |
| `…/state/render-inputs/` | export overlay/title inputs |
| `…/state/logs/service.log` | helper log |
| `…/state/run/{s.sock,token}` | the Unix socket and per-launch token |
| `~/Library/Application Support/com.sportcut.sportcut/sportcut.db` | the catalog |

The state root is local to the app and is never inside a synced Documents
folder, so macOS does not ask for OneDrive/Documents access.

### Release protocol behaviour

The release client sends `matchId` only. A release service rejects a
client-supplied `matchDir`; it resolves `<state-root>/matches/<id>` itself. The
client's match paths are aligned to that layout, and its recordings root is
`<state-root>/recordings`, which the service may read directly.

## 5. Verify the install

- `flutter analyze` is clean and `tools/verify-engine.sh` passes on the source
  you packaged.
- The app launches and shows the library without a service error banner.
- `pgrep -fl 'Contents/Helpers/SportcutService'` shows the helper with the state
  root and ffmpeg arguments above.
- `~/Library/Application Support/com.sportcut.sportcut/state/run/token` exists.
- Import a short `.mov` or `.mp4`, then run **Prepare analysis** and confirm
  `proxy/`, `audio/`, and `frames/` appear under the match directory.
- `service.health` (through the socket or the app’s status surface) reports
  `status: ok` and `toolchain.available: true`.

For a protocol-level check without the UI, ask the running service for
`service.health` and `engine.probe` over `state/run/s.sock` with the token; the
framing is the length-prefixed JSON-RPC in
[protocol.md](../../architecture/protocol.md).

## 6. Upgrade, rollback, uninstall

**Upgrade.** Quit the app, replace it in Applications with the new build, and
relaunch. Matches and artifacts remain under Application Support.

**Rollback.** Keep the previous `sportcut.app`; replace the new one. The catalog
schema has not changed in this build, so older and newer builds read the same
data. No migration is performed.

**Uninstall.** Quit the app and move it to the Trash. Remove data only if you
mean to:

```bash
rm -rf ~/Library/Application\ Support/com.sportcut.sportcut
```

That removes the catalog, match artifacts, service recordings, and logs.

## 7. Limits of this build

This is a **personal, local build**:

- Ad-hoc signed unless `CODESIGN_IDENTITY` was set; no notarisation.
- The app is **unsandboxed** so it can launch the helper and read the
  service-owned recording store.
- It uses the Mac's installed ffmpeg/ffprobe. The Homebrew ffmpeg is GPL
  (`--enable-gpl`), fine locally but **not shippable**.
- It does not supervise the helper as a launchd-managed process; a force-quit
  can leave the helper running, and the next launch reuses it.
- It has no updater, installer package, or App Store packaging.

A distributable release needs ADR-0001 Phase 6 work: a supervised helper
(launchd or XPC), a sandbox and entitlement design, a licensed media toolchain,
Developer ID signing plus notarisation, and an update path. The distribution
matrix is in
[background-service.md §9.5](../../architecture/background-service.md#95-distribution-matrix).

## See also

- Run the pieces from a checkout: [desktop-app.md](desktop-app.md)
- Engine and service details: [engine-and-service.md](engine-and-service.md)
- Failures: [troubleshooting.md](troubleshooting.md)
