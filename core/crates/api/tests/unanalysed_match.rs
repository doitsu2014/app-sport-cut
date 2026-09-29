//! A match the client imported but has not analysed yet.
//!
//! Import only takes custody of the recording; the match directory and its
//! manifest appear when analysis files are produced. Reading suggestions or
//! tracks before then must report "none", not a file-system error.

use std::path::Path;

use sportcut_api::{
    match_player_tracks, match_rally_suggestions, start_rally_segmentation,
    PlayerTrackWindowRequestDto, RallySegmentationConfigDto, RallySegmentationRequestDto,
};
use sportcut_storage::ArtifactManifest;

fn request(match_dir: &Path) -> RallySegmentationRequestDto {
    RallySegmentationRequestDto {
        match_dir: match_dir.to_string_lossy().to_string(),
        config: RallySegmentationConfigDto {
            bin_ms: 500,
            max_track_gap_ms: 2_000,
            enter_motion_per_second: 4.0,
            exit_motion_per_second: 2.0,
            audio_intensity_threshold: 0.5,
            min_rally_ms: 1_500,
            min_rest_ms: 3_000,
            min_usable_coverage: 0.40,
        },
    }
}

#[test]
fn a_match_without_a_manifest_has_no_suggestions_or_tracks() {
    let root = tempfile::tempdir().expect("tempdir");
    let match_dir = root.path().join("match-never-prepared");

    let suggestions = match_rally_suggestions(request(&match_dir)).expect("no error");
    assert!(suggestions.is_none());

    let tracks = match_player_tracks(PlayerTrackWindowRequestDto {
        match_dir: match_dir.to_string_lossy().to_string(),
        start_seconds: 0.0,
        end_seconds: 10.0,
    })
    .expect("no error");
    assert!(tracks.is_none());
}

#[test]
fn a_manifest_without_tracks_has_no_suggestions() {
    let root = tempfile::tempdir().expect("tempdir");
    let mut manifest = ArtifactManifest::new("m1", &root.path().join("original.mov"));
    manifest
        .save(&root.path().join("manifest.json"))
        .expect("save manifest");

    let suggestions = match_rally_suggestions(request(root.path())).expect("no error");
    assert!(suggestions.is_none());
}

#[test]
fn analysing_a_match_without_tracks_says_what_is_missing() {
    let root = tempfile::tempdir().expect("tempdir");
    let error = start_rally_segmentation(request(&root.path().join("missing")))
        .expect_err("nothing to analyse");
    assert!(
        error.to_string().contains("player tracks are unavailable"),
        "{error}"
    );
}

#[test]
fn an_unreadable_manifest_is_still_an_error() {
    let root = tempfile::tempdir().expect("tempdir");
    std::fs::write(root.path().join("manifest.json"), "not json").expect("write");

    assert!(match_rally_suggestions(request(root.path())).is_err());
}
