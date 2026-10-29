# macOS — engine and background service

The Rust half of the product, headless. Nothing here needs Flutter or Xcode.

## Build and test the engine

```bash
tools/verify-engine.sh
```

That runs, in order: `tools/check-layering.sh`, `cargo fmt --check`,
`cargo clippy --workspace --all-targets -- -D warnings`, and
`cargo test --workspace`.

For day-to-day work, the cheapest applicable check is enough:

```bash
cd core
cargo build --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

The media tests generate their own fixtures with `ffmpeg`. Without `ffmpeg`
installed, that subset cannot run — install it rather than skipping the tests
that need it.

### The layering check

```bash
tools/check-layering.sh
```

It derives each crate's layer from its directory (`entities/`, `use-cases/`,
`gateways/`, `adapters/`, `drivers/`) and fails on any dependency that points
outward. It reads the manifests only; it does not build. Needs `jq`.

The layer model and the one declared exception are in
[`docs/architecture/layering.md`](../../architecture/layering.md).

## Build the service

```bash
tools/build-service.sh
```

Produces `core/target/release/sportcut-service`. On macOS the script enables the
`macos-tflite-eval` feature by default, which is what makes player tracking
available; set `SPORTCUT_MACOS_TFLITE_EVAL=0` to build without it. Without that
feature the service starts normally and reports tracking as unsupported.

The service is a separate executable. It is never a dylib and never linked into
the app ([ADR-0001](../../adr/0001-rust-background-service.md)).

## Run the service for development

```bash
tools/run-service.sh
```

The script builds and starts the service, prints the socket endpoint and the
token file path, and waits. By default the state root is a fresh temporary
directory that is removed on exit.

| Flag | Effect |
| --- | --- |
| `--state-root <path>` | Keep data across runs, at a path you choose |
| `--keep` | Keep the temporary state root and print where it is |

Keeping a state root matters when you want to re-open a match after restarting
the service: matches, recordings, artifacts, and the catalog live under it.

### What the service needs at runtime

- `ffmpeg` and `ffprobe` on `PATH`, or `SPORTCUT_FFMPEG` / `SPORTCUT_FFPROBE`
  set, or `--ffmpeg` / `--ffprobe` passed.
- For player tracking, a TensorFlow Lite runtime and a person model. When the
  inference flags are absent the service looks for
  `Contents/Frameworks/libtensorflowlite_c.dylib` and
  `Contents/Resources/model.tflite`, then falls back to
  `SPORTCUT_TFLITE_LIBRARY` and `SPORTCUT_PERSON_MODEL`.
- `service.health` reports whether inference is actually usable, not merely
  whether a file exists: it checks the runtime and the model fingerprint.

The service never accepts a client-supplied runtime or model path.

## Talking to it

The wire contract is [`docs/architecture/protocol.md`](../../architecture/protocol.md).
For a quick manual check, see its worked examples; `service.hello` is the
required first call, and the token is in the file printed at startup.

Two behaviours worth knowing while testing by hand:

- one heavy job at a time; a second start is rejected synchronously with
  `job_rejected`;
- the service exits on idle, so a paused session may find the socket gone and
  must reconnect.

## Where to go next

- Run the client: [desktop-app.md](desktop-app.md)
- Package it: [packaging.md](packaging.md)
- Something failed: [troubleshooting.md](troubleshooting.md)
