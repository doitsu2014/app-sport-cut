## 1. Confirm Wave 3 inputs and evidence

- [ ] 1.1 Complete or integrate `add-rally-rest-segmentation` and the Wave 2 tracking artifact; document the accepted rally, track, calibration, and optional audio snapshot contract used by both new stages.
- [ ] 1.2 Obtain consented labeled rally footage and evaluate candidate local side cues for singles and doubles; set a documented precision and abstention threshold before enabling winner suggestions.
- [ ] 1.3 Record licensing and distribution verdicts for any newly selected runtime, weights, dataset, audio component, or codec before adding it to a shipping path.

## 2. Score suggestions

- [ ] 2.1 Implement a typed, versioned `sportcut-score` request/result that returns a side, confidence, and evidence explanation or an explicit abstention for each reviewed rally.
- [ ] 2.2 Implement only side cues meeting the documented threshold; make missing, contradictory, or low-quality evidence abstain without changing confirmed winners or score events.
- [ ] 2.3 Expose score insights through `sportcut-api` with input identity and cancellation/progress when analysis is long; reject or mark stale results after boundary, calibration, track, or evidence changes.
- [ ] 2.4 Add suggestion display to the score review flow while preserving independent left, right, and skip actions and the confirmed-only score timeline.

## 3. Highlight ranking

- [ ] 3.1 Implement `sportcut-highlight` ranking over reviewed rallies with bounded duration, normalized movement, optional audio, and confirmed score features; document weights, missing-signal handling, and deterministic tie-breaking.
- [ ] 3.2 Expose per-rally scores, ranks, feature reasons, coverage, and input identity through the typed API and Dart wrapper without writing ranking output into the user-owned reel.
- [ ] 3.3 Show unkept rallies in recommendation order with reasons and uncertainty; keep selection explicit and preserve clip trims and user order when ranking changes.
- [ ] 3.4 Invalidate or refresh score-context rankings after a winner correction and media-feature rankings after a boundary or artifact change, without deleting user-authored records.

## 4. Integration and verification

- [ ] 4.1 Regenerate bridge bindings with `tools/generate-bridge.sh` after API changes and keep generated files uncommitted.
- [ ] 4.2 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets -- -D warnings`, and `flutter analyze`; resolve findings in the touched tracks.
- [ ] 4.3 Check the documented side-cue and ranking behavior against representative local footage, including silent and sparse-track recordings; record evidence when this change is explicitly verified or closed.
- [ ] 4.4 Update the Wave 3 roadmap and user guidance to describe suggestion confidence, abstention, ranked recommendations, and continued user control.
