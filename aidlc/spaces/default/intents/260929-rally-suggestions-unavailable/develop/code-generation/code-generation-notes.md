# Code Generation Notes

- `cargo fmt --all`: ok.
- `cargo clippy -p sportcut-api --all-targets -- -D warnings`: ok.
- There are no deviations from the requirements.
- The working tree also holds the uncommitted accuracy-harness feature. This
  fix touches only `core/crates/api/src/facade.rs` plus its new test file, so
  it can be committed or branched on its own.
