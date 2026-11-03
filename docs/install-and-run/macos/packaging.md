# macOS — production packaging and install (DMG)

This is the deployment path for installing Sportcut on a Mac: build a release
bundle with the background service, media toolchain, model, and TFLite runtime
embedded, sign it, and write a DMG. The installed app has no runtime
dependency on Homebrew or anything else outside the bundle.

The build is **self-contained**. It is ad-hoc signed unless a Developer ID is
supplied, and notarisation runs when a `notarytool` profile is named. The
remaining limits are listed at the end; the architecture behind the helper is in
[background-service.md §9](../../architecture/background-service.md#9-sandbox-packaging-signing-and-notarization).

## 1. Before you package

```bash
tools/preflight.sh --profile macos
```

Required on the build machine:

- Xcode (a full installation, not Command Line Tools).
- Rust 1.80+ with `cargo` and `rustup` (the universal helper needs the second
  Rust standard library, which `tools/build-service.sh` installs on demand).
- Flutter with Dart 3.
- `clang`, `make`, `lipo`, and `tar`. They come with the Xcode toolchain.
- Network access at build time: `tools/build-media-toolchain.sh` downloads the
  pinned FFmpeg source, and `tools/fetch-inference-assets.sh` downloads the
  TFLite assets if they are not already in `third_party/inference/`.

You do **not** need `ffmpeg` installed on the build machine or on the Mac that
installs the app. The packaging script builds a license-clean, universal
ffmpeg/ffprobe from source and embeds it.

If Flutter is not on `PATH`, set `SPORTCUT_FLUTTER_BIN` to the directory that
contains the `flutter` executable.

## 2. Build the DMG

```bash
tools/package-macos.sh
# → dist/Sportcut.dmg
```

The script runs these steps:

1. `tools/build-service.sh` — release `sportcut-service` for `arm64` and
   `x86_64`, combined with `lipo`, with `macos-tflite-eval` enabled by default
   on macOS.
2. `tools/build-media-toolchain.sh` — FFmpeg 9.0.2 built LGPL-only, static,
   universal, with the native `mpeg4`/`aac` encoders and the pipeline's
   decoders and filters. The first run compiles it; later runs reuse
   `third_party/media-toolchain/`.
3. `tools/fetch-inference-assets.sh` when the TFLite runtime and model are not
   already present.
4. `flutter build macos --release` — the universal client bundle.
5. Embedding:
   - `Contents/Helpers/SportcutService` — the service helper;
   - `Contents/Helpers/ffmpeg` and `Contents/Helpers/ffprobe` — the media
     toolchain;
   - `Contents/Frameworks/libtensorflowlite_c.dylib` — the TFLite runtime;
   - `Contents/Resources/model.tflite` — the model;
   - `Contents/Resources/licenses/` — FFmpeg's LGPL and license texts.
6. Codesign the nested binaries, then the outer app.
7. `hdiutil` to write `dist/Sportcut.dmg`. The DMG also carries
   `Licenses/ffmpeg-9.0.2.tar.xz`, its license texts, and
   `build-media-toolchain.sh` — the corresponding source and build recipe
   required by the LGPL for a static build.

`dist/` and `third_party/` are build output and are git-ignored.

### Signing and notarisation

By default the build is **ad-hoc signed**:

```bash
tools/package-macos.sh
```

The app carries `app/macos/Runner/Release.entitlements` (file-picker access; the
sandbox is off for this build), every nested executable and dylib is signed, and
then the outer app is signed. Ad-hoc signing deliberately omits the hardened
runtime so the helper can load the ad-hoc dylib.

With a Developer ID identity, everything is signed with a real identity:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  tools/package-macos.sh
```

To produce a build Gatekeeper accepts without a right-click, create a notary
profile once and pass it:

```bash
xcrun notarytool store-credentials sportcut-notary \
  --apple-id "you@example.com" --team-id TEAMID \
  --password "app-specific-password"

CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  NOTARY_PROFILE=sportcut-notary tools/package-macos.sh
```

The script signs the DMG, submits it with `notarytool --wait`, staples the
ticket, and validates it. Notarisation requires network access and an Apple
Developer account; it is skipped when `NOTARY_PROFILE` is unset.

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
3. Launch it. A signed and notarised build opens normally. An ad-hoc build
   needs right-click → **Open** the first time, or **System Settings → Privacy &
   Security → Open Anyway** if macOS does not offer the context menu. If the
   copy was downloaded, macOS may attach a quarantine flag; clearing it is the
   same consent:

   ```bash
   xattr -dr com.apple.quarantine /Applications/sportcut.app
   ```

There is nothing else to install: ffmpeg, ffprobe, the service helper, the
TFLite runtime, and the model all live inside the bundle.

## 4. What the installed app does

On launch, if neither `SPORTCUT_ENDPOINT` nor `SPORTCUT_STATE_ROOT` is set, the
app starts the embedded helper itself
(`app/lib/src/bridge/service_supervisor.dart`):

```
Contents/Helpers/SportcutService
  --state-root  ~/Library/Application Support/com.sportcut.sportcut/state
  --endpoint    …/state/run/s.sock
  --token-file  …/state/run/token
  --ffmpeg      Contents/Helpers/ffmpeg
  --ffprobe     Contents/Helpers/ffprobe
  --tflite-library Contents/Frameworks/libtensorflowlite_c.dylib
  --person-model   Contents/Resources/model.tflite
```

The bundled media tools win; a development run that starts the helper without
them still falls back to Homebrew or `PATH`. The inference arguments are only
passed on Apple Silicon running macOS 15 or later, because the bundled TFLite
runtime is an arm64 build with a 15.0 deployment target.

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

- The bundle is self-contained and universal:

  ```bash
  APP=/Volumes/Sportcut/sportcut.app
  lipo -archs "$APP/Contents/Helpers/ffmpeg"        # x86_64 arm64
  lipo -archs "$APP/Contents/Helpers/SportcutService"
  codesign --verify --deep --strict "$APP"
  "$APP/Contents/Helpers/ffmpeg" -hide_banner -version   # no --enable-gpl
  ```

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

- Ad-hoc signed unless `CODESIGN_IDENTITY` was set, and not notarised unless
  `NOTARY_PROFILE` was set as well. Without both, Gatekeeper asks for a
  right-click on first launch.
- The app is **unsandboxed** so it can launch the helper and read the
  service-owned recording store.
- The bundled media toolchain is FFmpeg's LGPL configuration. It has no GPL
  components and carries no external dylib paths, but it is not the
  platform-native renderer named in the export roadmap; H.264/AAC patent
  licensing remains a legal decision (R-4 in the product context).
- The bundled TFLite runtime is an **Apple Silicon build with a macOS 15.0
  deployment target**; player tracking is unavailable on Intel Macs and on
  macOS 12–14. Probe, proxy, audio, frames, export, and every non-tracking
  engine stage run on both slices from macOS 12.
- It does not supervise the helper as a launchd-managed process; a force-quit
  can leave the helper running, and the next launch reuses it.
- It has no updater or App Store packaging.

A fully distributable release still needs ADR-0001 Phase 6 work: a supervised
helper (launchd or XPC), a sandbox and entitlement design, and an update path.
The distribution matrix is in
[background-service.md §9.5](../../architecture/background-service.md#95-distribution-matrix).

## See also

- Run the pieces from a checkout: [desktop-app.md](desktop-app.md)
- Engine and service details: [engine-and-service.md](engine-and-service.md)
- Failures: [troubleshooting.md](troubleshooting.md)
