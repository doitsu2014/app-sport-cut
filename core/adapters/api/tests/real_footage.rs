//! End-to-end rally analysis on a real recording.
//!
//! This is the reference measurement the synthetic unit tests cannot give: it
//! imports a local badminton recording, marks the court, runs local person
//! detection and tracking, then segments rallies. It is opt-in because it needs
//! footage the repository does not carry and the trial TFLite runtime.
//!
//! Run it with:
//!
//! ```text
//! SPORTCUT_TEST_VIDEO=/path/to/match.mov \
//! SPORTCUT_TEST_VIDEO_CORNERS='[[0.18,1.0],[0.81,1.0],[0.69,0.37],[0.40,0.37]]' \
//! cargo test -p sportcut-api --features macos-tflite-eval \
//!   --test real_footage -- --nocapture
//! ```
//!
//! `SPORTCUT_TEST_VIDEO_CORNERS` is four normalized `[x, y]` corners in the
//! order the app marks them: near-left, near-right, far-right, far-left. The
//! default is the rear-baseline doubles court measured on the IMG_1308 clip;
//! override it for any other camera. Without `SPORTCUT_TEST_VIDEO` the test
//! reports that it skipped and passes, so ordinary `cargo test` is unaffected.
//!
//! When the variable is set, the test fails — it does not skip — if the file,
//! runtime, or model is missing. That keeps a CI run without assets from
//! reporting a false green.
//!
//! Optional clip trimming keeps a development run short:
//! `SPORTCUT_TEST_VIDEO_START` (seconds) and `SPORTCUT_TEST_VIDEO_SECONDS`
//! (duration). A trimmed run asserts the structural invariants and the active
//! fraction, not the full-reference rally-count gate. The source file is never
//! modified.
//!
//! `SPORTCUT_TEST_ENFORCE_BUDGET=1` (or an optimized build) enforces the 300 s
//! acceptance budget; every run prints per-stage and total wall time.

#![cfg(all(target_os = "macos", feature = "macos-tflite-eval"))]

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

use sportcut_api::track_artifact::{TrackArtifact, PLAYER_TRACKS_RELATIVE_PATH};
use sportcut_api::{
    job_status, match_manifest, match_player_tracks, match_rally_suggestions,
    save_match_calibration, start_import, start_player_tracking, start_rally_segmentation,
    ArtifactStateDto, CalibrationSaveRequestDto, CalibrationSegmentDto, CourtCalibrationDto,
    CourtCornerDto, CourtOrientationDto, JobStateDto, MediaImportRequestDto,
    PlayerTrackWindowRequestDto, PlayerTrackingConfigDto, PlayerTrackingRequestDto,
    RallySegmentationConfigDto, RallySegmentationRequestDto,
};
use sportcut_court::CourtSide;
use sportcut_vision::{CandidateDecision, ObservedCount, TrackingResult};

/// Corners measured on a rear-baseline doubles view (IMG_1308.MOV).
const DEFAULT_CORNERS: [[f64; 2]; 4] = [
    [0.1802, 0.9981],
    [0.8094, 0.9981],
    [0.6938, 0.3704],
    [0.4031, 0.3704],
];

/// The supported trial detector and runtime shipped in `third_party/inference`.
const MODEL_RELATIVE: &str = "third_party/inference/model.tflite";
const RUNTIME_RELATIVE: &str = "third_party/inference/libtensorflowlite_c.dylib";

/// The detector confidence floor used by the app and this measurement.
const MIN_CONFIDENCE: f32 = 0.2;

/// Acceptance floors measured on the full reference before the association fix.
const BEFORE_ON_COURT_DETECTIONS: usize = 21_672;
const BEFORE_RAW_DETECTIONS: usize = 22_667;
const BEFORE_COUNT_SUPPORTING_FRAMES: usize = 150;

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .ancestors()
        .nth(3)
        .expect("the crate lives three levels below the repository root")
        .to_path_buf()
}

fn timeout() -> Duration {
    let seconds = std::env::var("SPORTCUT_TEST_TIMEOUT_SECONDS")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(1_800);
    Duration::from_secs(seconds)
}

fn wait_for(label: &str, job_id: &str) {
    let deadline = Instant::now() + timeout();
    let mut last = String::new();
    loop {
        let status = job_status(job_id.to_string()).expect("a job status is readable");
        let line = format!(
            "{label}: {:?} stage={:?} progress={:?}",
            status.state, status.stage, status.progress
        );
        if line != last {
            eprintln!("{line}");
            last = line;
        }
        match status.state {
            JobStateDto::Completed => return,
            JobStateDto::Failed => {
                panic!("{label} failed: {}", status.error.unwrap_or_default())
            }
            JobStateDto::Cancelled => panic!("{label} was cancelled"),
            JobStateDto::Pending | JobStateDto::Running => {}
        }
        assert!(
            Instant::now() < deadline,
            "{label} did not finish within {:?}",
            timeout()
        );
        std::thread::sleep(Duration::from_millis(500));
    }
}

/// Unset means the opt-in test does not run. Set means it must run: a missing
/// path is a failure, not a silent skip.
fn test_video() -> Option<PathBuf> {
    let raw = std::env::var_os("SPORTCUT_TEST_VIDEO")?;
    let path = PathBuf::from(raw);
    assert!(
        path.is_file(),
        "SPORTCUT_TEST_VIDEO is set but is not a file: {}",
        path.display()
    );
    Some(path)
}

fn trimmed_window() -> bool {
    std::env::var_os("SPORTCUT_TEST_VIDEO_START").is_some()
        || std::env::var_os("SPORTCUT_TEST_VIDEO_SECONDS").is_some()
}

/// Trim a development window with ffmpeg when the env asks for one.
fn prepared_video(source: &Path, directory: &Path) -> PathBuf {
    let start: Option<f64> = std::env::var("SPORTCUT_TEST_VIDEO_START")
        .ok()
        .and_then(|value| value.parse().ok());
    let seconds: Option<f64> = std::env::var("SPORTCUT_TEST_VIDEO_SECONDS")
        .ok()
        .and_then(|value| value.parse().ok());
    if start.is_none() && seconds.is_none() {
        return source.to_path_buf();
    }
    let output = directory.join("real-footage-window.mov");
    let mut command = Command::new("ffmpeg");
    command.arg("-v").arg("error").arg("-y");
    if let Some(start) = start {
        command.arg("-ss").arg(start.to_string());
    }
    command.arg("-i").arg(source);
    if let Some(seconds) = seconds {
        command.arg("-t").arg(seconds.to_string());
    }
    command
        .arg("-map")
        .arg("0:v:0")
        .arg("-map")
        .arg("0:a:0?")
        .arg("-c:v")
        .arg("copy")
        .arg("-c:a")
        .arg("aac")
        .arg(&output);
    let status = command
        .status()
        .expect("ffmpeg is available for clip trimming");
    assert!(status.success(), "ffmpeg could not trim the test recording");
    output
}

fn corners() -> Vec<CourtCornerDto> {
    let pairs: Vec<[f64; 2]> = match std::env::var("SPORTCUT_TEST_VIDEO_CORNERS") {
        Ok(raw) => serde_json::from_str(&raw).expect("corners are a JSON array of four [x, y]"),
        Err(_) => DEFAULT_CORNERS.to_vec(),
    };
    assert_eq!(pairs.len(), 4, "four court corners are required");
    pairs
        .into_iter()
        .map(|[x, y]| CourtCornerDto { x, y })
        .collect()
}

fn tracking_config(sampling_rate: f64) -> PlayerTrackingConfigDto {
    PlayerTrackingConfigDto {
        sampling_rate,
        min_confidence: MIN_CONFIDENCE,
        court_margin: 0.04,
        net_margin: 0.05,
        max_track_gap_ms: 1_200,
        max_frame_gap_ms: 500,
        max_ground_speed_per_second: 0.8,
        ambiguity_margin: 0.1,
        min_track_observations: 3,
        min_count_frames: 5,
        min_count_fraction: 0.7,
    }
}

fn rally_config() -> RallySegmentationConfigDto {
    RallySegmentationConfigDto {
        bin_ms: 500,
        max_track_gap_ms: 2_000,
        enter_motion_per_second: 3.5,
        exit_motion_per_second: 1.5,
        audio_intensity_threshold: 0.5,
        min_rally_ms: 1_500,
        min_rest_ms: 3_000,
        min_usable_coverage: 0.40,
    }
}

/// Recomputed RQ-01 figures from the review evidence.
struct RecomputedFragmentation {
    raw: usize,
    on_court: usize,
    observations: HashMap<u64, usize>,
    sides: HashMap<u64, (bool, bool)>,
}

/// Recompute the pinned RQ-01 definition from the review evidence.
fn recompute_fragmentation(
    review: &TrackingResult,
    min_confidence: f32,
) -> RecomputedFragmentation {
    let mut on_court = 0_usize;
    let mut raw = 0_usize;
    let mut observations = HashMap::<u64, usize>::new();
    let mut sides = HashMap::<u64, (bool, bool)>::new();
    for frame in &review.frames {
        for person in &frame.people {
            if person.candidate.detection.confidence >= min_confidence {
                raw += 1;
            }
            if person.candidate.decision != CandidateDecision::OnCourt {
                continue;
            }
            on_court += 1;
            if let Some(track_id) = person.track_id {
                *observations.entry(track_id).or_default() += 1;
                if let Some(side) = person.candidate.side {
                    let entry = sides.entry(track_id).or_insert((false, false));
                    match side {
                        CourtSide::First => entry.0 = true,
                        CourtSide::Second => entry.1 = true,
                    }
                }
            }
        }
    }
    RecomputedFragmentation {
        raw,
        on_court,
        observations,
        sides,
    }
}

fn top_four(observations: &HashMap<u64, usize>) -> Vec<(u64, usize)> {
    let mut counts: Vec<(u64, usize)> = observations
        .iter()
        .map(|(id, count)| (*id, *count))
        .collect();
    counts.sort_by(|left, right| right.1.cmp(&left.1).then(left.0.cmp(&right.0)));
    counts.truncate(4);
    counts
}

#[test]
fn a_real_recording_produces_tracks_and_rallies() {
    let Some(video) = test_video() else {
        eprintln!("skipped: SPORTCUT_TEST_VIDEO is not set");
        return;
    };
    let root = repo_root();
    let runtime = root.join(RUNTIME_RELATIVE);
    let model = root.join(MODEL_RELATIVE);
    assert!(
        runtime.is_file() && model.is_file(),
        "SPORTCUT_TEST_VIDEO is set but the inference assets are missing; \
         run tools/fetch-inference-assets.sh (expected {} and {})",
        runtime.display(),
        model.display()
    );

    // `SPORTCUT_TEST_KEEP` keeps the match directory for inspection after a
    // failed measurement; otherwise it lives in a temporary directory.
    let keep = std::env::var_os("SPORTCUT_TEST_KEEP").map(PathBuf::from);
    let temporary = if keep.is_none() {
        Some(tempfile::tempdir().expect("temporary match directory"))
    } else {
        None
    };
    let work_dir = match &keep {
        Some(root) => {
            fs::create_dir_all(root).expect("keep directory");
            root.clone()
        }
        None => temporary
            .as_ref()
            .expect("temporary directory is present")
            .path()
            .to_path_buf(),
    };
    let video = prepared_video(&video, &work_dir);
    let trimmed = trimmed_window();
    let match_dir = work_dir.join("match-real-footage");
    let _ = fs::remove_dir_all(&match_dir);
    let match_dir_string = match_dir.to_string_lossy().to_string();

    eprintln!("importing {}", video.display());
    let import_started = Instant::now();
    let import = start_import(MediaImportRequestDto {
        match_id: "real-footage".to_string(),
        original_path: video.to_string_lossy().to_string(),
        match_dir: match_dir_string.clone(),
        sampling_rate: 1.0,
    })
    .expect("import is admitted");
    wait_for("import", &import.job_id);
    let import_elapsed = import_started.elapsed();

    let manifest = match_manifest(match_dir_string.clone()).expect("manifest is readable");
    // Audio is optional on the source, so only the media rally analysis reads
    // is required here.
    for kind in ["proxy", "frames"] {
        assert!(
            manifest
                .artifacts
                .iter()
                .any(|artifact| artifact.kind == kind && artifact.state == ArtifactStateDto::Final),
            "import must publish a final {kind} artifact"
        );
    }

    let geometry = save_match_calibration(CalibrationSaveRequestDto {
        match_dir: match_dir_string.clone(),
        calibration: CourtCalibrationDto {
            schema_version: 1,
            segments: vec![CalibrationSegmentDto {
                from_ms: 0,
                corners: corners(),
                orientation: CourtOrientationDto::Away,
            }],
        },
    })
    .expect("the court is saved");
    assert_eq!(geometry.geometry.len(), 1);

    eprintln!("tracking players at 5 fps");
    let tracking_started = Instant::now();
    let tracking = start_player_tracking(PlayerTrackingRequestDto {
        match_dir: match_dir_string.clone(),
        config: tracking_config(5.0),
        runtime_path: Some(runtime.to_string_lossy().to_string()),
        model_path: Some(model.to_string_lossy().to_string()),
    })
    .expect("tracking is admitted");
    wait_for("tracking", &tracking.job_id);
    let tracking_elapsed = tracking_started.elapsed();

    let tracks = match_player_tracks(PlayerTrackWindowRequestDto {
        match_dir: match_dir_string.clone(),
        start_seconds: 0.0,
        end_seconds: 5.0,
    })
    .expect("tracks are readable")
    .expect("a completed tracking run publishes tracks");
    assert!(
        !tracks.coverage.is_empty(),
        "a completed tracking run records attempted coverage"
    );

    let artifact_path = match_dir.join(PLAYER_TRACKS_RELATIVE_PATH);
    let artifact_bytes = fs::read(&artifact_path).expect("the track artifact is readable");
    let artifact: TrackArtifact =
        serde_json::from_slice(&artifact_bytes).expect("the track artifact deserializes");
    let review = artifact
        .review
        .as_ref()
        .expect("a completed track generation carries review evidence");
    let summary = review
        .fragmentation
        .expect("a completed track generation records the fragmentation summary");
    let provenance = artifact
        .provenance
        .as_ref()
        .expect("a completed track generation records provenance");

    let recomputed = recompute_fragmentation(review, provenance.tracking.court.min_confidence);
    let on_court = recomputed.on_court;
    let raw = recomputed.raw;
    let observations = &recomputed.observations;
    let sides = &recomputed.sides;
    let top = top_four(observations);
    let top_four_observations: usize = top.iter().map(|(_, count)| count).sum();
    let broad_share = if on_court == 0 {
        0.0
    } else {
        top_four_observations as f64 / on_court as f64
    };
    assert_eq!(summary.raw_detections, raw, "raw denominator agrees");
    assert_eq!(
        summary.on_court_detections, on_court,
        "on-court denominator agrees"
    );
    assert_eq!(
        summary.distinct_tracks,
        observations.len(),
        "distinct identities agree"
    );
    assert_eq!(
        summary.top_four_observations, top_four_observations,
        "top-four numerator agrees"
    );
    assert!(
        (summary.top_four_share - broad_share).abs() < 1e-12,
        "engine summary and independent recomputation disagree"
    );
    eprintln!(
        "fragmentation: top-four {}/{} = {:.1}% of on-court detections \
         ({:.2}/frame, {} identities), count {:?} ({:.1}%, {} supporting frames)",
        top_four_observations,
        on_court,
        broad_share * 100.0,
        on_court as f64 / review.frames.len() as f64,
        observations.len(),
        review.count.count,
        review.count.quality * 100.0,
        review.count.supporting_frames,
    );

    // RQ-03: only OnCourt boxes carry IDs and every tracked point is on court.
    let margin = provenance.tracking.court.court_margin;
    for frame in &review.frames {
        for person in &frame.people {
            if person.track_id.is_none() {
                continue;
            }
            assert_eq!(
                person.candidate.decision,
                CandidateDecision::OnCourt,
                "only an on-court box may carry a track ID"
            );
            let court = person
                .candidate
                .court_point
                .expect("a tracked box has a court point");
            assert!(
                (0.0..=1.0).contains(&court.u) && (0.0..=1.0).contains(&court.v),
                "a tracked court point is inside the court"
            );
        }
    }
    for position in &artifact.input.positions {
        assert!(
            (-margin..=1.0 + margin).contains(&position.u)
                && (-margin..=1.0 + margin).contains(&position.v),
            "every compact position is inside the court margin"
        );
    }

    // RQ-04: no short-lived fragment enters the compact rally input.
    let minimum_observations = provenance.tracking.min_track_observations;
    let input_ids: HashSet<u64> = artifact
        .input
        .positions
        .iter()
        .map(|position| position.track_id)
        .collect();
    for position in &artifact.input.positions {
        let observed = observations.get(&position.track_id).copied().unwrap_or(0);
        assert!(
            observed >= minimum_observations,
            "compact input retained track {} with only {observed} observations",
            position.track_id
        );
    }
    let short_ids: Vec<u64> = observations
        .iter()
        .filter(|(_, count)| **count < minimum_observations)
        .map(|(id, _)| *id)
        .collect();
    if short_ids.is_empty() {
        eprintln!("note: the run contains no short-lived track to exercise review retention");
    } else {
        for id in short_ids {
            assert!(
                !input_ids.contains(&id),
                "a short-lived track leaked into the compact input"
            );
        }
    }

    // RQ-02: Four only at the approved floor; Unknown carries its evidence.
    let min_count_frames = provenance.tracking.min_count_frames;
    let min_count_fraction = provenance.tracking.min_count_fraction;
    match review.count.count {
        ObservedCount::Four => {
            assert!(
                review.count.quality >= 0.60,
                "Four requires at least 60% supporting frames, got {:.3}",
                review.count.quality
            );
            assert!(review.count.supporting_frames >= min_count_frames);
        }
        ObservedCount::Unknown => {
            assert!((0.0..=1.0).contains(&review.count.quality));
            assert!(review.count.evidence.end_ms > review.count.evidence.start_ms);
            assert!(
                review.count.supporting_frames < min_count_frames
                    || review.count.quality < min_count_fraction,
                "Unknown must not be reported when the count floor is met"
            );
        }
        ObservedCount::Two => panic!("a doubles recording should report Four or Unknown, not Two"),
    }
    assert_eq!(
        tracks.count_supporting_frames, review.count.supporting_frames,
        "the DTO exposes the count evidence"
    );
    assert_eq!(
        tracks
            .track_quality
            .map(|quality| quality.top_four_share)
            .unwrap_or(-1.0),
        summary.top_four_share,
        "the DTO exposes the fragmentation summary"
    );

    eprintln!("segmenting rallies");
    let rally_started = Instant::now();
    let rally = start_rally_segmentation(RallySegmentationRequestDto {
        match_dir: match_dir_string.clone(),
        config: rally_config(),
    })
    .expect("rally analysis is admitted");
    wait_for("rally", &rally.job_id);
    let rally_elapsed = rally_started.elapsed();

    let suggestions = match_rally_suggestions(RallySegmentationRequestDto {
        match_dir: match_dir_string,
        config: rally_config(),
    })
    .expect("suggestions are readable")
    .expect("the completed run publishes suggestions for its exact inputs");

    assert!(suggestions.generation_id.starts_with("rally-"));
    assert!(!suggestions.timeline.is_empty());
    let duration = suggestions
        .timeline
        .last()
        .expect("a non-empty timeline has a last span")
        .end_seconds;
    assert!(duration > 0.0);
    assert_eq!(suggestions.timeline[0].start_seconds, 0.0);
    let mut next_start = 0.0;
    for span in &suggestions.timeline {
        assert_eq!(span.start_seconds, next_start, "the timeline has no gaps");
        assert!(
            span.end_seconds > span.start_seconds,
            "every span has a positive duration"
        );
        next_start = span.end_seconds;
    }

    let rally_spans: Vec<_> = suggestions
        .timeline
        .iter()
        .filter(|span| span.kind == "rally")
        .collect();
    assert_eq!(suggestions.candidates.len(), rally_spans.len());
    let minimum_rally_seconds = rally_config().min_rally_ms as f64 / 1000.0;
    for (candidate, span) in suggestions.candidates.iter().zip(&rally_spans) {
        assert_eq!(candidate.start_seconds, span.start_seconds);
        assert_eq!(candidate.end_seconds, span.end_seconds);
        assert!(
            candidate.end_seconds - candidate.start_seconds >= minimum_rally_seconds,
            "min_rally_ms is the floor for every candidate"
        );
        assert!((0.0..=1.0).contains(&candidate.quality));
    }

    let rally_seconds: f64 = rally_spans
        .iter()
        .map(|span| span.end_seconds - span.start_seconds)
        .sum();
    let active_fraction = rally_seconds / duration;
    let total_elapsed = import_elapsed + tracking_elapsed + rally_elapsed;
    eprintln!(
        "measured: {:.1}s recording, {} rallies, {:.0}s rally time ({:.0}%), \
         top-four {}/{} = {:.1}% of on-court detections ({} identities, {:.2}/frame), \
         count {:?} ({:.0}%, {} supporting frames), usable coverage {:.0}%, \
         import {:.1}s + tracking {:.1}s + rally {:.1}s = {:.1}s",
        duration,
        suggestions.candidates.len(),
        rally_seconds,
        active_fraction * 100.0,
        top_four_observations,
        on_court,
        broad_share * 100.0,
        observations.len(),
        on_court as f64 / review.frames.len() as f64,
        review.count.count,
        review.count.quality * 100.0,
        review.count.supporting_frames,
        suggestions.usable_coverage * 100.0,
        import_elapsed.as_secs_f64(),
        tracking_elapsed.as_secs_f64(),
        rally_elapsed.as_secs_f64(),
        total_elapsed.as_secs_f64(),
    );

    assert!(
        suggestions.usable_coverage >= 0.5,
        "a court that was marked on this footage must yield usable tracks"
    );
    if trimmed {
        assert!(
            (0.02..=0.60).contains(&active_fraction),
            "rally time must stay a plausible fraction of a trimmed window"
        );
    } else {
        assert!(
            (30..=40).contains(&suggestions.candidates.len()),
            "RQ-05: expected 30-40 rallies, found {}",
            suggestions.candidates.len()
        );
        assert!(
            (0.10..=0.30).contains(&active_fraction),
            "RQ-05: active time {:.1}% is outside 10-30%",
            active_fraction * 100.0
        );
    }

    // The track gates run after the rally measurement so a failing share still
    // produces the complete evidence line.
    if !trimmed {
        assert!(
            raw >= BEFORE_RAW_DETECTIONS.saturating_sub(1_000),
            "the raw detection denominator shrank below the measured baseline: {raw}"
        );
        assert!(
            on_court >= BEFORE_ON_COURT_DETECTIONS.saturating_sub(1_000),
            "the on-court denominator shrank below the measured baseline: {on_court}"
        );
        let per_frame = on_court as f64 / review.frames.len() as f64;
        assert!(
            (5.0..=9.0).contains(&per_frame),
            "on-court detections per frame left the measured band: {per_frame:.2}"
        );
        let largest = top.first().map(|(_, count)| *count).unwrap_or(0);
        assert!(
            largest as f64 <= 0.40 * top_four_observations as f64,
            "one identity dominates the top four; a false join may be inflating the share"
        );
        let mut first = false;
        let mut second = false;
        for (id, _) in &top {
            if let Some((has_first, has_second)) = sides.get(id) {
                first |= *has_first;
                second |= *has_second;
            }
        }
        assert!(
            first && second,
            "the four longest tracks must cover both court sides"
        );
        assert!(
            review.count.supporting_frames >= BEFORE_COUNT_SUPPORTING_FRAMES,
            "count evidence regressed below the measured baseline: {} supporting frames",
            review.count.supporting_frames
        );
        assert!(
            summary.top_four_share >= 0.60,
            "RQ-01 failed: top-four share {:.1}% is below 60% \
             (denominator {on_court}, numerator {top_four_observations})",
            summary.top_four_share * 100.0
        );
    }

    if !cfg!(debug_assertions) || std::env::var_os("SPORTCUT_TEST_ENFORCE_BUDGET").is_some() {
        assert!(
            total_elapsed <= Duration::from_secs(300),
            "RQ-09: the full reference run took {:.1}s, over the 300 s budget",
            total_elapsed.as_secs_f64()
        );
    }
}
