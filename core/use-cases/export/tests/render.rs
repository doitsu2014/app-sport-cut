//! Rendering, exercised against real fixtures and the real toolchain.
//!
//! The assertions here are about what came out of the encoder — which clip is
//! where, how long the reel is, whether the overlay is in the pixels, what the
//! audio does — rather than about the arguments the renderer built. A golden
//! file would pin the local encoder's output instead of the edit list's
//! contract, and this development toolchain is a GPL build whose output is not
//! the one the shipping backend will produce.
//!
//! Every test skips, rather than fails, when the media toolchain is missing.

mod support;

use std::path::{Path, PathBuf};

use sportcut_common::CancelToken;
use sportcut_export::{
    render, EditClip, EditList, ExportContext, TitleCard, STAGE_FINALIZE, STAGE_PREPARE,
    STAGE_RENDER,
};
use support::{
    content_hash, fixtures, CancelWhenEncoding, Fixtures, RecordingProgress, BOX_HEIGHT, BOX_WIDTH,
    BOX_X, BOX_Y, HEIGHT, WIDTH,
};

/// How long the title card is shown.
const TITLE_SECONDS: f64 = 1.5;

/// Lead-in and lead-out padding asked for around each clip.
const PADDING_SECONDS: f64 = 0.5;

/// The reel the tests render: the red half of the fixture, then the blue half.
///
/// With half a second of padding on both sides, clip one covers source 0.0–2.0
/// and clip two covers source 2.5–4.5, so the reel runs 1.5–5.5 seconds in
/// total once the title card is in front.
const CLIPS_SECONDS: f64 = 4.0;
const REEL_SECONDS: f64 = CLIPS_SECONDS + TITLE_SECONDS;

/// Where the first clip's source material appears in the reel.
const FIRST_CLIP_REEL_SECONDS: f64 = 2.0;
const FIRST_CLIP_SOURCE_SECONDS: f64 = 0.5;

/// Where the second clip's source material appears in the reel.
const SECOND_CLIP_REEL_SECONDS: f64 = 4.5;
const SECOND_CLIP_SOURCE_SECONDS: f64 = 3.5;

/// A corner region the overlay does not cover.
const CORNER: (u32, u32, u32, u32) = (0, 0, 40, 40);

fn edit_list(source: &Path, output: &Path) -> EditList {
    let mut edit_list = EditList::new(source, output);
    edit_list.clips = vec![
        EditClip {
            start_seconds: 0.5,
            end_seconds: 1.5,
            overlay: None,
        },
        EditClip {
            start_seconds: 3.0,
            end_seconds: 4.0,
            overlay: None,
        },
    ];
    edit_list.lead_in_seconds = PADDING_SECONDS;
    edit_list.lead_out_seconds = PADDING_SECONDS;
    edit_list
}

/// Render a reel, insisting that it succeeded.
fn render_ok(edit_list: &EditList, fixtures: &Fixtures) -> sportcut_export::RenderOutput {
    let progress = RecordingProgress::default();
    let context = ExportContext {
        cancel: CancelToken::new(),
        progress: &progress,
    };
    let output = render(edit_list, fixtures.toolchain(), &context).expect("the reel renders");

    // The stages the client watches are all reported, in order.
    let stages: Vec<String> = progress
        .events()
        .into_iter()
        .map(|event| event.stage)
        .collect();
    for stage in [STAGE_PREPARE, STAGE_RENDER, STAGE_FINALIZE] {
        assert!(stages.contains(&stage.to_string()), "{stages:?}");
    }

    output
}

fn assert_close(actual: f64, expected: f64, tolerance: f64, what: &str) {
    assert!(
        (actual - expected).abs() <= tolerance,
        "{what}: expected {expected} ± {tolerance}, got {actual}"
    );
}

#[test]
fn a_rendered_reel_holds_the_clips_in_order_with_padding_and_a_title() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("source.mp4", true);
    let title = fixtures.title("title.png", "0x102030");
    let output = fixtures.path("reel/highlight.mp4");
    let source_before = content_hash(&source);

    let mut edit_list = edit_list(&source, &output);
    edit_list.title = Some(TitleCard {
        image: title.clone(),
        seconds: TITLE_SECONDS,
    });

    let rendered = render_ok(&edit_list, &fixtures);
    assert_eq!(rendered.clip_count, 2);
    assert!(rendered.size_bytes > 0);
    assert_close(rendered.duration_seconds, REEL_SECONDS, 0.01, "reel length");
    assert_close(
        fixtures.duration(&output),
        REEL_SECONDS,
        0.3,
        "probed reel length",
    );

    // The title card comes first: the opening frames are the card the
    // application drew, not the recording.
    let card = fixtures.region_stats(&title, 0.0, 0, 0, WIDTH, HEIGHT);
    let opening = fixtures.region_stats(&output, 0.75, 0, 0, WIDTH, HEIGHT);
    assert_close(opening.y, card.y, 20.0, "title brightness");
    assert_close(opening.v, card.v, 20.0, "title red channel");

    // A frame two seconds into the reel is the first clip's red source
    // material, and one at 4.5 seconds is the second clip's blue material: the
    // clips are in the order the edit list asked for, at the padded boundaries
    // it asked for.
    let first_source = fixtures.region_stats(
        &source,
        FIRST_CLIP_SOURCE_SECONDS,
        CORNER.0,
        CORNER.1,
        CORNER.2,
        CORNER.3,
    );
    let first_reel = fixtures.region_stats(
        &output,
        FIRST_CLIP_REEL_SECONDS,
        CORNER.0,
        CORNER.1,
        CORNER.2,
        CORNER.3,
    );
    assert!(
        first_source.redness() > 40.0,
        "the fixture's first half should be red: {first_source:?}"
    );
    assert!(
        first_reel.redness() > 40.0,
        "the first clip should be the red half: {first_reel:?}"
    );
    assert_close(first_reel.v, first_source.v, 20.0, "first clip red channel");

    let second_source = fixtures.region_stats(
        &source,
        SECOND_CLIP_SOURCE_SECONDS,
        CORNER.0,
        CORNER.1,
        CORNER.2,
        CORNER.3,
    );
    let second_reel = fixtures.region_stats(
        &output,
        SECOND_CLIP_REEL_SECONDS,
        CORNER.0,
        CORNER.1,
        CORNER.2,
        CORNER.3,
    );
    assert!(
        second_source.redness() < -40.0,
        "the fixture's second half should be blue: {second_source:?}"
    );
    assert!(
        second_reel.redness() < -40.0,
        "the second clip should be the blue half: {second_reel:?}"
    );
    assert_close(
        second_reel.u,
        second_source.u,
        20.0,
        "second clip blue channel",
    );

    // The recording itself is read, never written.
    assert_eq!(content_hash(&source), source_before);

    // No music was asked for, so the title card is silent and the match audio
    // waits for the picture rather than starting under the card.
    let title_window = fixtures.mean_volume_db(&output, 0.2, 1.0);
    assert!(
        title_window < -60.0,
        "the title card should be silent without music: {title_window} dB"
    );
    let clip_window = fixtures.mean_volume_db(&output, 1.6, 1.6);
    assert!(
        clip_window > -50.0,
        "the clip should carry the match audio: {clip_window} dB"
    );
}

#[test]
fn the_overlay_is_composited_into_the_encoded_frames() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("source.mp4", true);
    let overlay = fixtures.overlay("overlay.png");
    let output = fixtures.path("reel/highlight.mp4");

    let mut edit_list = edit_list(&source, &output);
    for clip in &mut edit_list.clips {
        clip.overlay = Some(overlay.clone());
    }
    edit_list.title = Some(TitleCard {
        image: fixtures.title("title.png", "0x102030"),
        seconds: TITLE_SECONDS,
    });

    render_ok(&edit_list, &fixtures);

    // The box the overlay draws is over the second, blue, clip: the pixels
    // inside it are the overlay's own colour, not the recording's.
    let drawn = fixtures.region_stats(&overlay, 0.0, BOX_X, BOX_Y, BOX_WIDTH, BOX_HEIGHT);
    let composed = fixtures.region_stats(
        &output,
        SECOND_CLIP_REEL_SECONDS,
        BOX_X,
        BOX_Y,
        BOX_WIDTH,
        BOX_HEIGHT,
    );
    assert!(
        drawn.redness() > 40.0,
        "the overlay box should be red: {drawn:?}"
    );
    assert!(
        composed.redness() > 40.0,
        "the scoreboard should be burned into the frame: {composed:?}"
    );
    assert_close(composed.v, drawn.v, 25.0, "overlay red channel");
    assert_close(composed.u, drawn.u, 25.0, "overlay blue channel");

    // Everywhere else the recording shows through: the same frame's corner is
    // still the blue clip, so the overlay is a composite and not a replacement.
    let corner = fixtures.region_stats(
        &output,
        SECOND_CLIP_REEL_SECONDS,
        CORNER.0,
        CORNER.1,
        CORNER.2,
        CORNER.3,
    );
    assert!(
        corner.redness() < -40.0,
        "the recording should show through outside the scoreboard: {corner:?}"
    );
}

#[test]
fn a_recording_without_an_audio_track_renders_video_only() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("silent.mp4", false);
    let output = fixtures.path("reel/highlight.mp4");
    let edit_list = edit_list(&source, &output);

    render_ok(&edit_list, &fixtures);

    assert_eq!(fixtures.streams(&output), vec!["video".to_string()]);
    // No title card here, so the reel is just the two padded clips.
    assert_close(
        fixtures.duration(&output),
        CLIPS_SECONDS,
        0.3,
        "reel length",
    );
}

#[test]
fn the_reel_carries_the_match_audio() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("source.mp4", true);
    let output = fixtures.path("reel/highlight.mp4");
    let edit_list = edit_list(&source, &output);

    render_ok(&edit_list, &fixtures);

    let streams = fixtures.streams(&output);
    assert!(streams.contains(&"video".to_string()), "{streams:?}");
    assert!(streams.contains(&"audio".to_string()), "{streams:?}");
    let clip_window = fixtures.mean_volume_db(&output, 1.6, 1.6);
    assert!(
        clip_window > -50.0,
        "the clip should carry the match audio: {clip_window} dB"
    );
}

#[test]
fn music_shorter_than_the_reel_plays_under_it_to_the_end() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("source.mp4", true);
    let music = fixtures.music("music.m4a", 1.0);
    let output = fixtures.path("reel/highlight.mp4");

    let mut edit_list = edit_list(&source, &output);
    edit_list.title = Some(TitleCard {
        image: fixtures.title("title.png", "0x102030"),
        seconds: TITLE_SECONDS,
    });
    edit_list.music = Some(music);
    edit_list.music_gain = 0.3;

    render_ok(&edit_list, &fixtures);

    // The music is what is audible under the card, and it still covers the
    // reel's last moments instead of stopping when the one-second track ran
    // out.
    let under_the_card = fixtures.mean_volume_db(&output, 0.2, 1.0);
    assert!(
        under_the_card > -50.0,
        "the music should play under the title card: {under_the_card} dB"
    );
    let at_the_end = fixtures.mean_volume_db(&output, REEL_SECONDS - 1.2, 1.0);
    assert!(
        at_the_end > -60.0,
        "the music should reach the end of the reel: {at_the_end} dB"
    );
    assert_close(fixtures.duration(&output), REEL_SECONDS, 0.3, "reel length");
}

#[test]
fn a_cancelled_export_leaves_no_partial_reel() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let source = fixtures.two_colour_video("source.mp4", true);
    let fresh = edit_list(&source, &fixtures.path("fresh/highlight.mp4"));

    // Nothing was there before, and nothing must be there after.
    let cancel = CancelToken::new();
    let progress = CancelWhenEncoding::new(cancel.clone(), STAGE_RENDER);
    let context = ExportContext {
        cancel,
        progress: &progress,
    };
    let error = render(&fresh, fixtures.toolchain(), &context)
        .expect_err("a cancelled render must not report success");
    assert!(error.is_cancellation(), "{error}");
    assert!(
        !fresh.output.exists(),
        "a cancelled export must not produce the reel"
    );

    // A reel the user already had is what a cancelled re-render must leave
    // alone: the render writes a partial file and renames only on success.
    let previous = fixtures.path("kept/highlight.mp4");
    std::fs::create_dir_all(previous.parent().expect("a parent directory"))
        .expect("create the export directory");
    std::fs::write(&previous, b"the reel the user already had").expect("write the previous reel");
    let before = content_hash(&previous);

    let mut kept = edit_list(&source, &previous);
    kept.title = Some(TitleCard {
        image: fixtures.title("title.png", "0x102030"),
        seconds: TITLE_SECONDS,
    });
    let cancel = CancelToken::new();
    let progress = CancelWhenEncoding::new(cancel.clone(), STAGE_RENDER);
    let context = ExportContext {
        cancel,
        progress: &progress,
    };
    let error = render(&kept, fixtures.toolchain(), &context)
        .expect_err("a cancelled render must not report success");
    assert!(error.is_cancellation(), "{error}");
    assert_eq!(
        content_hash(&previous),
        before,
        "the previous reel was replaced by a cancelled render"
    );

    let leftovers: Vec<PathBuf> = std::fs::read_dir(previous.parent().expect("a parent directory"))
        .expect("read the export directory")
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| {
            path.extension()
                .is_some_and(|extension| extension == "part")
        })
        .collect();
    assert!(
        leftovers.is_empty(),
        "a cancelled render left a partial file behind: {leftovers:?}"
    );
}
