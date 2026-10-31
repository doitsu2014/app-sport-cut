# Install and run

How to get Sportcut running on a machine, per platform. These are operator and
developer instructions; the design behind them is in
[`docs/architecture/`](../architecture/README.md).

| Platform | Status | Guide |
| --- | --- | --- |
| macOS | Shipping target | [macos/](macos/README.md) |
| Linux, Windows | Not a product target | The engine builds, but there is no client |

## What "install" means here

There are two different things, and they have different instructions:

- **Run the product.** A signed `sportcut.app` with the background service
  embedded as a helper. That is a packaging concern; see
  [macos/packaging.md](macos/packaging.md).
- **Run the project from a checkout.** Build the engine, run the service, run
  the Flutter client. That is a development concern; start at
  [macos/README.md](macos/README.md).

## Current state

The client reaches the engine over the service protocol. It links no Rust and
carries no generated bindings; the FFI path is gone.

- **Installed app:** the release bundle contains the helper and inference
  assets, and the app starts and supervises the helper itself against a state
  root under Application Support. `tools/package-macos.sh` produces a personal
  DMG; see [macos/packaging.md](macos/packaging.md).
- **From a checkout:** the service is started separately with
  `tools/run-service.sh`, and the client connects over the Unix socket; see
  [macos/desktop-app.md](macos/desktop-app.md).

What remains of the migration — catalog ownership, recording custody, and a
supervised/sandboxed packaged helper — is in the
[migration plan](../architecture/migration-from-ffi.md). The packaged build is
a personal install, not a distributable release.
