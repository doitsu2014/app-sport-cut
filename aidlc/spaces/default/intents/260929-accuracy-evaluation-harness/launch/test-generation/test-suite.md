# Test Suite

## Files

| File | Tests | Plan IDs |
| --- | --- | --- |
| `core/crates/eval/src/labels.rs` `#[cfg(test)]` | 4 | T-1, T-2 |
| `core/crates/eval/src/metrics.rs` `#[cfg(test)]` | 7 | T-3, T-4, T-5 |
| `core/crates/eval/tests/fixture.rs` | 8 | T-6..T-13 |
| `core/crates/eval/tests/fixtures/synthetic.labels.json` | fixture | hand-written, no footage |
| `core/crates/eval/tests/fixtures/synthetic.player_tracks.json` | fixture | minimal envelope; the unknown `provenance` field proves the view ignores extra fields |

`git check-ignore` confirms the fixtures aren't ignored.

## Results

```text
cargo test -p sportcut-eval            unit 11 passed · integration 8 passed
tools/verify-engine.sh                 exit 0 (fmt, clippy -D warnings, workspace tests)
```

## T-14 CLI smoke (scratch data outside the repo)

| Case | Observed |
| --- | --- |
| Manifest with one good clip and one mismatched `clip_id` | Table printed; c2 is `error` with a named reason; exit 0 |
| Same with `--fail-on-target` | exit 3 |
| Single clip `--json` | Contract §4 shape; exit 0 |
| Single clip, missing tracks file | `cannot read …/tracks/player_tracks.json`; exit 1 |
| No `--manifest` / `--labels` | clap usage error; exit 2 |
| `--tolerance-ms -1` | `--tolerance-ms must not be negative`; exit 1 |
| Two `--json` runs | identical `shasum` |

## Defects found by testing

| # | Defect | Fix |
| --- | --- | --- |
| TD-1 | clap exits 2 on usage errors, which collides with the contract's "2 = target missed". | Target missed is now exit **3**. Contract, requirements, spec and docs updated. Clap's default is kept so the other subcommands are unchanged. |
| TD-2 | clap parsed `--tolerance-ms -1` as a flag, so the negative-value check never ran. | `allow_hyphen_values = true`. |
