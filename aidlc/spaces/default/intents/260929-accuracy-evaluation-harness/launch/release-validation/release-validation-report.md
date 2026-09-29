# Release Validation Report

## Verification (re-run on the final code)

`tools/verify-engine.sh` exits 0: fmt check, clippy `--workspace --all-targets
-D warnings`, and `cargo test --workspace` pass. `sportcut-eval` has 11 unit
tests and 8 integration tests.

## Requirement coverage

| Req | Evidence | Status |
| --- | --- | --- |
| FR-1 labels | `labels.rs` tests; fixture parse | ✅ |
| FR-2 manifest | `labels.rs` test; CLI smoke (mismatched id → error clip) | ✅ |
| FR-3 player count | `synthetic_clip_scores_exactly`, `player_count_requires_a_matching_known_count` | ✅ |
| FR-4 boundaries | metrics tests incl. max-matching counter-example; fixture 3/6 | ✅ |
| FR-5 confidently wrong | fixture 0.3333; empty → 0 | ✅ |
| FR-6 IoU | metrics + fixture 0.5185 | ✅ |
| FR-7 aggregate/targets | `aggregate_micro_averages_scored_clips_only`, `targets_pass_fail_and_report_missing_data` | ✅ |
| FR-8 CLI | T-14 smoke (exit 0/1/2/3) | ✅ exit code for target missed is 3, not 2 (TD-1) |
| FR-9 replay | `replay_rejects_invalid_config_and_segments_valid_tracks` | ✅ |
| FR-10 duration drift | `unusable_inputs_become_error_clips` | ✅ |
| NFR-1 determinism | `output_is_byte_identical_across_runs`; CLI shasum | ✅ |
| NFR-2 offline, no inference | `crates/eval/Cargo.toml` deps: common, rally, vision, serde only | ✅ |
| NFR-3 < 5 s for 10×60 min | Not measured; no labeled real clips yet | ⏳ open |
| NFR-4 verify script | exit 0 | ✅ |
| C-1..C-4 | No footage committed; no artifact schema change; pure crate; tests limited to the new crate | ✅ |

## Operational readiness

- Usage, label guide and metric definitions are in
  `docs/verification/accuracy-evaluation.md`.
- The crate is listed in `docs/architecture.md` and `core/README.md`. The
  roadmap Phase 0 row points at the harness.
- No new third-party dependencies. `Cargo.lock` only gains the local crate.

## Release decision

**Ready for human review and merge.** The code is complete and verified.

Two follow-ups remain. They are owner actions, not code:

1. Label `c1`, and ideally 4 or more other clips. Run `sportcut-cli eval` and
   record the first results row in the verification doc.
2. Measure NFR-3 on that run.

Nothing is committed yet. The branch `feat/accuracy-evaluation-harness` holds
the working-tree changes for human review (org memory: every change is reviewed
by a human before merge).
