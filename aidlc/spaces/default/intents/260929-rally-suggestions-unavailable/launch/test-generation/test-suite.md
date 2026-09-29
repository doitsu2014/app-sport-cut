# Test Suite

New file: `core/crates/api/tests/unanalysed_match.rs`. It uses tempdirs only
and needs neither ffmpeg nor a model.

| Test | Req | Without fix | With fix |
| --- | --- | --- | --- |
| `a_match_without_a_manifest_has_no_suggestions_or_tracks` | BR-1, BR-3 | FAIL (os error 2) | pass |
| `a_manifest_without_tracks_has_no_suggestions` | BR-2 | FAIL ("player tracks are unavailable") | pass |
| `analysing_a_match_without_tracks_says_what_is_missing` | BR-4 | FAIL (raw I/O error) | pass |
| `an_unreadable_manifest_is_still_an_error` | BR-5 | pass | pass (guard) |

"Without fix" was run with `facade.rs` stashed.
`tools/verify-engine.sh` exits 0 (BR-7).
