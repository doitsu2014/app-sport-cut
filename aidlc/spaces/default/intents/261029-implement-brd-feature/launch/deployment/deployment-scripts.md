# Deployment Scripts — none added

Intent: `261029-implement-brd-feature`

No deployment script is added or changed. The existing entry points remain the
supported ones:

- `tools/run-macos.sh` — developer run of the macOS client.
- `tools/build-service.sh` — the service binary.
- `tools/embed-service.sh <app>` and `tools/embed-inference-assets.sh <app>` —
  bundle contents.

The change is Dart client code under `app/lib/src/features/workspace/`; it
requires no packaging, signing, or bundling step.
