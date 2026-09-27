## 1. Engine serving-side derivation

- [x] 1.1 Implement `serving_sides` in `core/crates/score/src/lib.rs` with `RallyOutcome` / `ServingSide`, the winner-serves-next rule, and validation
- [x] 1.2 Add `RallySideDto`, `RallyOutcomeDto`, `ServingSideRequestDto`, `ServingSideDto` to `core/crates/api/src/dto.rs`
- [x] 1.3 Add the `serving_sides` facade in `core/crates/api/src/facade.rs` and the DTO conversion in `core/crates/api/src/convert.rs`
- [x] 1.4 Verify the engine track: `cargo fmt`, `cargo clippy`, `cargo test -p sportcut-score`

## 2. Bridge

- [x] 2.1 Regenerate the bridge with `tools/generate-bridge.sh`
- [x] 2.2 Add the typed `servingSides` wrapper and export the new DTOs in `app/lib/src/bridge/sportcut_engine.dart`

## 3. Client

- [x] 3.1 Compute serving sides for the open match from the engine and expose them to the score screen
- [x] 3.2 Show the suggested winner on unscored rally tiles in the score screen
- [x] 3.3 Show the serve indicator on the scoreboard
- [x] 3.4 Verify the client track: `flutter analyze`
