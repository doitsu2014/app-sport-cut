# CI Configuration — recommendation only

Status: Launch / CI Pipeline
Intent: `261029-implement-brd-feature`

## 1. Finding

The repository has no `.github/workflows/` directory and no other CI
configuration. This intent is a six-file client change with no build-system
change, so it does **not** add a pipeline. This document records the build
contract a future pipeline should automate.

## 2. Build contract

| Step | Command | Needed for |
| --- | --- | --- |
| Engine preflight | `tools/preflight.sh --profile engine` | Toolchain check, no install. |
| Engine verify | `tools/verify-engine.sh` | `cargo fmt --check`, clippy, tests. |
| Layering | `tools/check-layering.sh` | Clean Architecture dependency rule. |
| Client analysis | `cd app && flutter analyze` | Static analysis for this change. |
| Client tests | `cd app && flutter test` | Not run in this intent (Q3-A). |
| Service guard | `tools/check-no-rust-in-app.sh` | No Rust in the app. |

## 3. Proposed pipeline (not added)

```yaml
name: verify
on: [push, pull_request]
jobs:
  engine:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: tools/preflight.sh --profile engine
      - run: tools/verify-engine.sh
      - run: tools/check-layering.sh
  client:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: cd app && flutter pub get && flutter analyze
      - run: tools/check-no-rust-in-app.sh
```

## 4. Why it is not added here

- No CI exists to modify; adding one is an infrastructure change with its own
  decision (runner image, macOS cost, secret policy).
- Feature 1's definition of done does not require CI, and the guardrail is to
  keep the change scoped to one unit of work.
- Recorded as a future unit rather than done silently.
