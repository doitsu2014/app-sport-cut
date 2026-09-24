//! End-to-end coverage of the media pipeline scenarios in the
//! `media-pipeline` spec.

mod support;

use std::sync::Arc;

use sportcut_common::{CancelToken, ProgressSink, SportcutError};
use sportcut_media::{
    expected_frame_count, extract_analysis_audio, generate_proxy, probe, regenerate_missing, run,
    sample_frames, validate_sampling_rate, FrameSamplingOptions, MediaToolchain, PipelineContext,
    PipelineOptions, ProxyOptions, MAX_SAMPLING_RATE,
};
use sportcut_storage::{ArtifactKind, ArtifactManifest, ArtifactState};
use support::{fixtures, CancelOnStage, Fixtures, RecordingProgress};

fn toolchain(fixtures: &Fixtures) -> MediaToolchain {
    fixtures.toolchain.clone()
}

#[test]
fn probe_returns_metadata_for_a_readable_file() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("probe.mp4", 320, 240, 10, 2.0, true);

    let metadata = probe(&video, &toolchain(&fixtures)).expect("probe should succeed");

    assert!(
        (metadata.duration_seconds - 2.0).abs() < 0.5,
        "{metadata:?}"
    );
    assert!((metadata.frame_rate - 10.0).abs() < 0.5, "{metadata:?}");
    assert_eq!((metadata.width, metadata.height), (320, 240));
    assert!(metadata.has_audio);
    assert_eq!(metadata.rotation_degrees, 0);
    assert!(metadata.size_bytes > 0);
}

#[test]
fn probe_reports_missing_truncated_and_non_media_inputs() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let toolchain = toolchain(&fixtures);

    let missing = fixtures.path("does-not-exist.mp4");
    let error = probe(&missing, &toolchain).expect_err("missing file must fail");
    match error {
        SportcutError::Probe { path, reason } => {
            assert!(path.contains("does-not-exist.mp4"), "{path}");
            assert_eq!(reason, "file not found");
        }
        other => panic!("unexpected error: {other}"),
    }

    let video = fixtures.video("source-truncated.mp4", 320, 240, 10, 2.0, true);
    let truncated = fixtures.truncated("truncated.mp4", &video);
    let error = probe(&truncated, &toolchain).expect_err("truncated file must fail");
    match error {
        SportcutError::Probe { path, reason } => {
            assert!(path.contains("truncated.mp4"), "{path}");
            assert!(!reason.is_empty());
        }
        other => panic!("unexpected error: {other}"),
    }

    let text = fixtures.text_file("notes.txt");
    let error = probe(&text, &toolchain).expect_err("non-media file must fail");
    assert!(matches!(error, SportcutError::Probe { .. }), "{error}");
}

#[test]
fn proxy_is_reduced_in_resolution_and_leaves_the_original_untouched() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("proxy-source.mp4", 640, 480, 10, 2.0, true);
    let before = support::content_hash(&video);

    let output = fixtures.path("proxy/out.mp4");
    let proxy = generate_proxy(
        &video,
        &output,
        &toolchain(&fixtures),
        &ProxyOptions { max_height: 240 },
    )
    .expect("proxy generation should succeed");

    assert_eq!(proxy.height, 240, "{proxy:?}");
    assert_eq!(proxy.width, 320, "{proxy:?}");
    assert!(proxy.size_bytes > 0);
    assert_eq!(support::content_hash(&video), before, "original changed");
}

#[test]
fn audio_is_extracted_and_a_silent_pipeline_continues_without_it() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let toolchain = toolchain(&fixtures);

    let with_audio = fixtures.video("audio.mp4", 320, 240, 10, 2.0, true);
    let metadata = probe(&with_audio, &toolchain).expect("probe");
    let extracted = extract_analysis_audio(
        &with_audio,
        &fixtures.path("audio/analysis.m4a"),
        &toolchain,
        &metadata,
    )
    .expect("audio extraction should succeed");
    let path = extracted.expect("audio track should be extracted");
    assert!(path.is_file());

    let silent = fixtures.video("no-audio.mp4", 320, 240, 10, 2.0, false);
    let metadata = probe(&silent, &toolchain).expect("probe");
    assert!(!metadata.has_audio);
    let extracted = extract_analysis_audio(
        &silent,
        &fixtures.path("audio/none.m4a"),
        &toolchain,
        &metadata,
    )
    .expect("a missing audio track is an expected outcome");
    assert!(extracted.is_none());
}

#[test]
fn frames_are_sampled_at_the_requested_rate_with_original_timestamps() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("frames.mp4", 320, 240, 10, 2.0, true);
    let toolchain = toolchain(&fixtures);
    let metadata = probe(&video, &toolchain).expect("probe");

    let frames = sample_frames(
        &video,
        &fixtures.path("frames"),
        &toolchain,
        &FrameSamplingOptions { rate: 2.0 },
        &metadata,
    )
    .expect("frame sampling should succeed");

    assert!(
        (3..=5).contains(&frames.len()),
        "expected about 4 frames, got {}",
        frames.len()
    );
    for (index, frame) in frames.iter().enumerate() {
        assert_eq!(frame.index, index as u32);
        assert_eq!(frame.timestamp_ms, (index as i64) * 500);
        assert!(frame.path.is_file());
    }
    assert_eq!(expected_frame_count(&metadata, 2.0), 4);
}

#[test]
fn unsupported_and_invalid_sampling_rates_are_rejected() {
    let error = validate_sampling_rate(MAX_SAMPLING_RATE + 15.0).expect_err("must reject");
    match error {
        SportcutError::Unsupported { feature, detail } => {
            assert_eq!(feature, "sampling rate");
            assert!(detail.contains("exceeds"), "{detail}");
        }
        other => panic!("unexpected error: {other}"),
    }

    let error = validate_sampling_rate(0.0).expect_err("must reject");
    assert!(matches!(error, SportcutError::InvalidInput(_)), "{error}");
}

#[test]
fn pipeline_writes_artifacts_under_one_directory_and_records_them() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("match.mp4", 320, 240, 10, 2.0, true);
    let original_hash = support::content_hash(&video);
    let match_dir = fixtures.match_dir("match-1");
    let progress = RecordingProgress::default();

    let report = run(
        &match_dir,
        &toolchain(&fixtures),
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &[],
        &PipelineContext {
            cancel: CancelToken::new(),
            progress: &progress,
        },
    )
    .expect("pipeline should succeed");

    assert!(report.proxy.expect("proxy path").is_file());
    assert!(report.audio.expect("audio path").is_file());
    assert!(!report.frames.is_empty());

    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).expect("manifest");
    assert_eq!(manifest.artifacts.len(), 3);
    assert!(manifest
        .artifacts
        .iter()
        .all(|entry| entry.state == ArtifactState::Final));
    assert_eq!(
        manifest.original.path,
        std::fs::canonicalize(&video)
            .expect("canonical path")
            .to_string_lossy()
    );
    assert!(std::path::Path::new(&manifest.original.path).is_file());
    assert_eq!(support::content_hash(&video), original_hash);

    let summary = manifest.summarize(match_dir.root());
    assert!(summary.original_present);
    assert!(summary.missing.is_empty());
    assert_eq!(summary.complete.len(), 3);

    let stages: Vec<String> = progress
        .events()
        .into_iter()
        .map(|event| event.stage)
        .collect();
    for stage in ["probe", "proxy", "audio", "frames"] {
        assert!(stages.iter().any(|seen| seen == stage), "{stages:?}");
    }
}

#[test]
fn derived_artifacts_are_regenerable_without_re_importing() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("regenerate.mp4", 320, 240, 10, 2.0, true);
    let match_dir = fixtures.match_dir("match-2");
    let toolchain = toolchain(&fixtures);

    run(
        &match_dir,
        &toolchain,
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &[],
        &PipelineContext::default(),
    )
    .expect("initial pipeline run");

    // Simulate the user clearing derived artifacts to reclaim space.
    std::fs::remove_file(match_dir.resolve("proxy/proxy.mp4")).expect("remove proxy");
    std::fs::remove_dir_all(match_dir.resolve("frames")).expect("remove frames");

    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).expect("manifest");
    let mut missing = manifest.missing_artifacts(match_dir.root());
    missing.sort_by_key(|kind| format!("{kind:?}"));
    assert_eq!(missing.len(), 2, "{missing:?}");
    assert!(missing.contains(&ArtifactKind::Proxy));
    assert!(missing.contains(&ArtifactKind::Frames));

    let regenerated = regenerate_missing(
        &match_dir,
        &toolchain,
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &PipelineContext::default(),
    )
    .expect("regeneration should succeed");
    assert_eq!(regenerated.rebuilt.len(), 2);
    assert!(regenerated.not_rebuildable.is_empty());

    assert!(match_dir.resolve("proxy/proxy.mp4").is_file());
    assert!(match_dir.resolve("frames").is_dir());
    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).expect("manifest");
    assert!(manifest.missing_artifacts(match_dir.root()).is_empty());
    assert!(manifest
        .artifacts
        .iter()
        .all(|entry| entry.state == ArtifactState::Final));
}

#[test]
fn cancellation_marks_partial_artifacts_non_final() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("cancel.mp4", 320, 240, 10, 2.0, true);
    let match_dir = fixtures.match_dir("match-3");

    let token = CancelToken::new();
    let sink = CancelOnStage {
        token: token.clone(),
        stage: "proxy",
    };
    let sink: Arc<dyn ProgressSink> = Arc::new(sink);

    let error = run(
        &match_dir,
        &toolchain(&fixtures),
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &[],
        &PipelineContext {
            cancel: token,
            progress: sink.as_ref(),
        },
    )
    .expect_err("cancelled run must fail");
    assert!(error.is_cancellation(), "{error}");

    let manifest = ArtifactManifest::load(&match_dir.manifest_path()).expect("manifest");
    assert!(
        manifest
            .artifacts
            .iter()
            .all(|entry| entry.state == ArtifactState::NonFinal),
        "{:?}",
        manifest.artifacts
    );
    let summary = manifest.summarize(match_dir.root());
    assert!(summary.complete.is_empty(), "{summary:?}");
}

#[test]
fn a_stage_recorded_as_complete_is_not_re_executed() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("resume.mp4", 320, 240, 10, 2.0, true);
    let match_dir = fixtures.match_dir("match-4");
    let toolchain = toolchain(&fixtures);

    run(
        &match_dir,
        &toolchain,
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &[],
        &PipelineContext::default(),
    )
    .expect("initial run");

    let proxy_path = match_dir.resolve("proxy/proxy.mp4");
    let proxy_before = support::content_hash(&proxy_path);

    let skip = vec!["proxy".to_string()];
    let report = run(
        &match_dir,
        &toolchain,
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &skip,
        &PipelineContext::default(),
    )
    .expect("run with a checkpointed stage");

    assert!(
        report.skipped.contains(&"proxy".to_string()),
        "{:?}",
        report.skipped
    );
    assert_eq!(
        support::content_hash(&proxy_path),
        proxy_before,
        "a checkpointed stage was re-executed"
    );
}
