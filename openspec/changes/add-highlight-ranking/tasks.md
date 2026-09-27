## 1. Engine ranking

- [x] 1.1 Implement `rank` in `core/crates/highlight/src/lib.rs` with `HighlightRally` / `HighlightRank`, weighted blend, and validation
- [x] 1.2 Add `HighlightRallyDto`, `HighlightRankingRequestDto`, `HighlightRankDto` to `core/crates/api/src/dto.rs`
- [x] 1.3 Add `rank_highlights` facade in `core/crates/api/src/facade.rs` and the DTO conversion in `core/crates/api/src/convert.rs`
- [x] 1.4 Verify the engine track: `cargo fmt`, `cargo clippy`, `cargo test -p sportcut-highlight`

## 2. Bridge

- [x] 2.1 Regenerate the bridge with `tools/generate-bridge.sh`
- [x] 2.2 Add the typed `rankHighlights` wrapper and export the new DTOs in `app/lib/src/bridge/sportcut_engine.dart`

## 3. Client

- [x] 3.1 Record an accepted suggestion's quality as the rally's confidence through `MatchEditing.acceptSuggestion`, `EditingRepository`, and `RallyReviewController.accept`
- [x] 3.2 Compute a rally's score context from the score timeline and rank rallies in the highlights screen
- [x] 3.3 Show the ranked suggestions (best first) and add a "keep the best N" action in the highlights screen
- [x] 3.4 Verify the client track: `flutter analyze`
