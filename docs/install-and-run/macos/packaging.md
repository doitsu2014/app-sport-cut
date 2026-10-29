# macOS — packaging a signed app

Turning a checkout into a distributable `sportcut.app`: embedding the engine
library, the inference assets, and — for the target architecture — the
background service helper.

Read [background-service.md §9](../../architecture/background-service.md#9-sandbox-packaging-signing-and-notarization)
first. This page is the command sequence; that section is the reason each piece
is where it is.

## Before you package

```bash
tools/preflight.sh --profile macos --strict-license
```

`--strict-license` fails on a GPL ffmpeg build. GPL FFmpeg is not shippable, and
a package built against one cannot be released. An LGPL build is required.

## Step 1 — build the pieces

```bash
tools/build-service.sh            # core/target/release/sportcut-service
tools/fetch-inference-assets.sh   # TFLite runtime + person model, SHA-256 verified
```

`fetch-inference-assets.sh` runs at build time only and places assets in
`third_party/inference/` (override with `SPORTCUT_INFERENCE_DIR`). Nothing in
the running app downloads anything.

## Step 2 — build the app

```bash
cd app
flutter build macos --release
```

The bundle is `app/build/macos/Build/Products/Release/sportcut.app`.

## Step 3 — embed

Run these against the built bundle, in this order:

```bash
tools/embed-inference-assets.sh    app/build/macos/Build/Products/Release/sportcut.app
tools/embed-service.sh             app/build/macos/Build/Products/Release/sportcut.app
```

| Script | Puts | Where |
| --- | --- | --- |
| `embed-inference-assets.sh` | `libtensorflowlite_c.dylib` | `Contents/Frameworks` |
| | `model.tflite` | `Contents/Resources` |
| `embed-service.sh` | `sportcut-service` | `Contents/Helpers/SportcutService` |

The inference dylib goes in `Contents/Frameworks` rather than `Contents/MacOS`
so that dynamic loading by the service stays signing-safe. The service goes in
`Contents/Helpers` because it is a separately signed executable, not a library.

**No engine library is embedded.** The app does not link Rust; it connects to
the helper over the service protocol. A `libsportcut_api.dylib` in
`Contents/Frameworks` is a defect, and `tools/check-no-rust-in-app.sh` fails on
one.

## Step 4 — sign

`embed-service.sh` signs the helper when a signing identity is available:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  tools/embed-service.sh app/build/macos/Build/Products/Release/sportcut.app
```

Without `CODESIGN_IDENTITY` the script copies the helper, prints the exact
`codesign` command, and exits 0 — so packaging can proceed in CI without a
identity, and the signature step is explicit rather than silently skipped.

Sign the helper before the outer app is signed and notarized; a nested executable
signed after its container invalidates the container's seal.

## Checklist

- [ ] `preflight --strict-license` passes; ffmpeg is LGPL
- [ ] `tools/verify-engine.sh` passes
- [ ] the service and the inference assets are built
- [ ] both embed steps ran against the release bundle
- [ ] the bundle contains no Rust library
- [ ] the helper is signed, then the app is signed, then notarized
- [ ] the app launches on a clean Mac with no developer tools installed
- [ ] no Rust archive, `dylib`, or generated binding is copied into the Flutter
      framework without being accounted for in the signing plan

The distribution matrix — Developer ID versus Mac App Store, and which packaging
each uses — is in
[background-service.md §9.5](../../architecture/background-service.md#95-distribution-matrix).
