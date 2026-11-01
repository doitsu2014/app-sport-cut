//! Adapter between vision's reviewable tracks and rally's compact input contract.

use std::collections::HashMap;
use std::io::Read;
use std::path::Path;

use serde::{Deserialize, Serialize};
use sportcut_common::{CancelToken, Result, SportcutError};
use sportcut_media::{
    sample_frames_collect_only, SampledFrame, FRAMES_RELATIVE_PATH, PROXY_RELATIVE_PATH,
};
use sportcut_rally::{SegmentationInput, TimeSpan as RallyTimeSpan, TrackPosition};
use sportcut_storage::{
    save_manifest, ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory,
    CALIBRATION_RELATIVE_PATH,
};
use sportcut_vision::{CandidateDecision, TrackingConfig, TrackingResult};

/// Stable relative path consumed by the rally facade and owned by the engine.
pub const PLAYER_TRACKS_RELATIVE_PATH: &str = "tracks/player_tracks.json";

/// Content fingerprint of the pinned EfficientDet-Lite0 trial model.
///
/// The player-tracking job refuses any other model; the service's `vision`
/// health block applies the same gate so a present-but-unsupported model can
/// never report as runnable.
pub const TRIAL_MODEL_FINGERPRINT: &str = "fnv1a64:0a4c9e64faa2dae8";

/// The first producer schema retains the provisional `input` shape already read
/// by rally segmentation. Additional review fields are ignored by older readers.
pub const PLAYER_TRACKS_SCHEMA_VERSION: u32 = 1;

/// Exact inputs that identify one derived track generation.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackProvenance {
    /// Content identity of the frame artifact used for detection.
    pub frames_fingerprint: String,
    /// Content identity of the proxy from which frames were sampled.
    pub proxy_fingerprint: String,
    /// Content identity of `calibration/calibration.json`.
    pub calibration_id: String,
    /// Pinned runtime name and version.
    pub runtime_id: String,
    /// Pinned detector name and version.
    pub model_id: String,
    /// Content identity of the exact model bytes.
    pub model_fingerprint: String,
    /// Sampling rate used to extract detection frames.
    pub sampling_rate: f64,
    /// Court, association, and count parameters used for this generation.
    pub tracking: TrackingConfig,
}

impl TrackProvenance {
    /// Check that a producer has supplied every identity needed for freshness.
    pub fn validate(&self) -> Result<()> {
        if self.frames_fingerprint.trim().is_empty()
            || self.proxy_fingerprint.trim().is_empty()
            || self.calibration_id.trim().is_empty()
            || self.runtime_id.trim().is_empty()
            || self.model_id.trim().is_empty()
            || self.model_fingerprint.trim().is_empty()
        {
            return Err(invalid("track provenance is missing an input identity"));
        }
        if !self.sampling_rate.is_finite() || self.sampling_rate <= 0.0 {
            return Err(invalid("track sampling rate must be positive"));
        }
        self.tracking.validate()
    }

    /// Reject tracks whose calibration, proxy, or sampled-frame bytes have changed.
    pub fn validate_current_media(
        &self,
        match_dir: &MatchDirectory,
        manifest: &ArtifactManifest,
    ) -> Result<()> {
        self.validate()?;
        for (kind, relative_path) in [
            (ArtifactKind::Proxy, PROXY_RELATIVE_PATH),
            (ArtifactKind::Frames, FRAMES_RELATIVE_PATH),
            (ArtifactKind::Calibration, CALIBRATION_RELATIVE_PATH),
        ] {
            let entry = manifest
                .entry(kind)
                .ok_or_else(|| invalid("a track input is missing"))?;
            if entry.state != ArtifactState::Final || entry.relative_path != relative_path {
                return Err(invalid(
                    "a track input is not a completed supported artifact",
                ));
            }
        }
        let calibration_path = match_dir.resolve(CALIBRATION_RELATIVE_PATH);
        let calibration = std::fs::read(&calibration_path)
            .map_err(|error| SportcutError::io(&calibration_path, error))?;
        if content_fingerprint(&calibration) != self.calibration_id {
            return Err(invalid(
                "court calibration changed; run player tracking again",
            ));
        }
        let proxy_path = match_dir.resolve(PROXY_RELATIVE_PATH);
        if fingerprint_file(&proxy_path)? != self.proxy_fingerprint {
            return Err(invalid("analysis proxy changed; run player tracking again"));
        }
        let frames_dir = match_dir.resolve(FRAMES_RELATIVE_PATH);
        let samples = sample_frames_collect_only(&frames_dir, self.sampling_rate)?;
        if fingerprint_samples(&samples)? != self.frames_fingerprint {
            return Err(invalid("sampled frames changed; run player tracking again"));
        }
        Ok(())
    }
}

/// Completed player tracks plus the raw evidence needed for reviewer inspection.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrackArtifact {
    /// Version of this JSON envelope.
    pub schema_version: u32,
    /// Compact positions and coverage accepted by `sportcut-rally`.
    pub input: SegmentationInput,
    /// Full detection, side, count, gap, and quality evidence for a new producer.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub review: Option<TrackingResult>,
    /// Model, runtime, frame, calibration, and configuration identity.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provenance: Option<TrackProvenance>,
}

impl TrackArtifact {
    /// Convert a completed vision result into the existing rally input envelope.
    pub fn from_tracking(
        duration_ms: i64,
        result: TrackingResult,
        provenance: TrackProvenance,
    ) -> Result<Self> {
        provenance.validate()?;
        if duration_ms <= 0 || result.coverage.is_empty() {
            return Err(invalid("tracks have no calibrated recording coverage"));
        }
        let mut positions = Vec::new();
        for frame in &result.frames {
            for person in &frame.people {
                if person.candidate.decision != CandidateDecision::OnCourt
                    || person.association_ambiguous
                {
                    continue;
                }
                if let (Some(track_id), Some(point)) =
                    (person.track_id, person.candidate.court_point)
                {
                    positions.push(TrackPosition {
                        timestamp_ms: frame.timestamp_ms,
                        track_id,
                        u: point.u,
                        v: point.v,
                    });
                }
            }
        }
        if positions.is_empty() {
            return Err(invalid("tracks have no reliable court positions"));
        }
        // A track seen fewer times than the count minimum is detection noise,
        // not a player. Keeping those one-frame fragments would add their
        // jitter to every rally motion bin and let a background box inflate a
        // rest interval into a rally. The review evidence still carries them;
        // only the compact segmentation input is filtered.
        let mut observations = HashMap::<u64, usize>::new();
        for frame in &result.frames {
            for person in &frame.people {
                if let Some(track_id) = person.track_id {
                    *observations.entry(track_id).or_default() += 1;
                }
            }
        }
        let minimum = provenance.tracking.min_track_observations;
        positions.retain(|position| {
            observations.get(&position.track_id).copied().unwrap_or(0) >= minimum
        });
        if positions.is_empty() {
            return Err(invalid(
                "tracks have no reliable court positions after removing short-lived fragments",
            ));
        }
        let coverage = result
            .coverage
            .iter()
            .map(|span| RallyTimeSpan {
                start_ms: span.start_ms,
                end_ms: span.end_ms,
            })
            .collect();
        Ok(Self {
            schema_version: PLAYER_TRACKS_SCHEMA_VERSION,
            input: SegmentationInput {
                duration_ms,
                calibration_id: provenance.calibration_id.clone(),
                coverage,
                positions,
                audio: None,
            },
            review: Some(result),
            provenance: Some(provenance),
        })
    }
}

/// Publish a completed track generation under the stable match artifact path.
///
/// The caller must hold the match's job lease. Existing tracks are marked
/// non-final before the replacement begins, so interruption cannot leave the
/// manifest pointing at new bytes with an old final-state claim.
pub fn save_track_artifact(
    match_dir: &MatchDirectory,
    manifest: &mut ArtifactManifest,
    artifact: &TrackArtifact,
    cancel: &CancelToken,
) -> Result<()> {
    if artifact.schema_version != PLAYER_TRACKS_SCHEMA_VERSION
        || artifact.review.is_none()
        || artifact.provenance.is_none()
        || artifact.input.coverage.is_empty()
        || artifact.input.positions.is_empty()
    {
        return Err(invalid(
            "only a completed supported track generation can be published",
        ));
    }
    let provenance = artifact.provenance.as_ref().expect("checked above");
    provenance.validate()?;
    if artifact.input.calibration_id != provenance.calibration_id {
        return Err(invalid(
            "track calibration identity differs from its provenance",
        ));
    }
    provenance.validate_current_media(match_dir, manifest)?;
    cancel.check()?;
    let path = match_dir.resolve(PLAYER_TRACKS_RELATIVE_PATH);
    let parent = path
        .parent()
        .ok_or_else(|| invalid("track artifact has no directory"))?;
    std::fs::create_dir_all(parent).map_err(|error| SportcutError::io(parent, error))?;
    manifest.record_artifact(
        ArtifactKind::Tracks,
        PLAYER_TRACKS_RELATIVE_PATH,
        ArtifactState::NonFinal,
        None,
    );
    save_manifest(manifest, &match_dir.manifest_path())?;
    let bytes = serde_json::to_vec(artifact)
        .map_err(|error| SportcutError::Artifact(format!("could not serialize tracks: {error}")))?;
    let temporary = path.with_extension("json.writing");
    std::fs::write(&temporary, &bytes).map_err(|error| SportcutError::io(&temporary, error))?;
    cancel.check()?;
    std::fs::rename(&temporary, &path).map_err(|error| SportcutError::io(&path, error))?;
    cancel.check()?;
    manifest.record_artifact(
        ArtifactKind::Tracks,
        PLAYER_TRACKS_RELATIVE_PATH,
        ArtifactState::Final,
        Some(bytes.len() as u64),
    );
    save_manifest(manifest, &match_dir.manifest_path())
}

/// Content label shared with the existing rally and calibration readers.
pub fn content_fingerprint(bytes: &[u8]) -> String {
    let hash = bytes
        .iter()
        .fold(FNV_OFFSET, |hash, byte| fnv_byte(hash, *byte));
    format!("fnv1a64:{hash:016x}")
}

/// Stream a large proxy or model file into a stable local content identity.
pub fn fingerprint_file(path: &Path) -> Result<String> {
    let mut file = std::fs::File::open(path).map_err(|error| SportcutError::io(path, error))?;
    let mut hash = FNV_OFFSET;
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let count = file
            .read(&mut buffer)
            .map_err(|error| SportcutError::io(path, error))?;
        if count == 0 {
            break;
        }
        for byte in &buffer[..count] {
            hash = fnv_byte(hash, *byte);
        }
    }
    Ok(format!("fnv1a64:{hash:016x}"))
}

/// Fingerprint the exact sampled frame sequence, including names and timestamps.
pub fn fingerprint_samples(samples: &[SampledFrame]) -> Result<String> {
    if samples.is_empty() {
        return Err(invalid("sampled frames are missing"));
    }
    let mut hash = FNV_OFFSET;
    for sample in samples {
        let name = sample
            .path
            .file_name()
            .ok_or_else(|| invalid("sampled frame has no file name"))?;
        for byte in name.to_string_lossy().as_bytes() {
            hash = fnv_byte(hash, *byte);
        }
        for byte in sample.timestamp_ms.to_le_bytes() {
            hash = fnv_byte(hash, byte);
        }
        let mut file = std::fs::File::open(&sample.path)
            .map_err(|error| SportcutError::io(&sample.path, error))?;
        let mut buffer = [0_u8; 64 * 1024];
        loop {
            let count = file
                .read(&mut buffer)
                .map_err(|error| SportcutError::io(&sample.path, error))?;
            if count == 0 {
                break;
            }
            for byte in &buffer[..count] {
                hash = fnv_byte(hash, *byte);
            }
        }
    }
    Ok(format!("fnv1a64:{hash:016x}"))
}

const FNV_OFFSET: u64 = 0xcbf29ce484222325;

fn fnv_byte(hash: u64, byte: u8) -> u64 {
    (hash ^ u64::from(byte)).wrapping_mul(0x100000001b3)
}

fn invalid(message: &str) -> SportcutError {
    SportcutError::InvalidInput(format!("player tracks: {message}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use sportcut_court::{CourtPoint, ImagePoint};
    use sportcut_vision::{
        BoundingBox, ClassifiedDetection, CountAssessment, Detection, FrameTracking, ObservedCount,
        TrackedDetection, TrackingConfig, TrackingResult,
    };

    fn tracking_config() -> TrackingConfig {
        TrackingConfig {
            court: sportcut_vision::CourtCandidateConfig {
                min_confidence: 0.2,
                court_margin: 0.04,
                net_margin: 0.05,
            },
            max_track_gap_ms: 1_200,
            max_frame_gap_ms: 500,
            max_ground_speed_per_second: 0.8,
            ambiguity_margin: 0.03,
            min_track_observations: 3,
            min_count_frames: 5,
            min_count_fraction: 0.7,
        }
    }

    fn provenance() -> TrackProvenance {
        TrackProvenance {
            frames_fingerprint: "fnv1a64:1".to_string(),
            proxy_fingerprint: "fnv1a64:2".to_string(),
            calibration_id: "fnv1a64:3".to_string(),
            runtime_id: "runtime".to_string(),
            model_id: "model".to_string(),
            model_fingerprint: "fnv1a64:4".to_string(),
            sampling_rate: 5.0,
            tracking: tracking_config(),
        }
    }

    fn person(track_id: u64) -> TrackedDetection {
        TrackedDetection {
            candidate: ClassifiedDetection {
                detection: Detection {
                    bbox: BoundingBox {
                        x: 10.0,
                        y: 10.0,
                        width: 20.0,
                        height: 40.0,
                    },
                    confidence: 0.9,
                },
                ground_point: Some(ImagePoint::new(0.5, 0.5)),
                court_point: Some(CourtPoint::new(0.5, 0.5)),
                side: None,
                decision: CandidateDecision::OnCourt,
            },
            track_id: Some(track_id),
            association_ambiguous: false,
        }
    }

    fn frame(timestamp_ms: i64, people: Vec<TrackedDetection>) -> FrameTracking {
        FrameTracking {
            timestamp_ms,
            width: 100,
            height: 100,
            people,
        }
    }

    fn result_with(frames: Vec<FrameTracking>) -> TrackingResult {
        TrackingResult {
            frames,
            coverage: vec![sportcut_vision::TimeSpan {
                start_ms: 0,
                end_ms: 600,
            }],
            usable_coverage: vec![sportcut_vision::TimeSpan {
                start_ms: 0,
                end_ms: 600,
            }],
            gaps: Vec::new(),
            count: CountAssessment {
                count: ObservedCount::Unknown,
                evidence: sportcut_vision::TimeSpan {
                    start_ms: 0,
                    end_ms: 600,
                },
                quality: 0.0,
                supporting_frames: 0,
            },
            fragmentation: None,
        }
    }

    #[test]
    fn a_generation_with_only_short_tracks_is_rejected() {
        let frames = vec![frame(0, vec![person(1)])];
        let error = TrackArtifact::from_tracking(600, result_with(frames), provenance())
            .expect_err("every position is filtered out");
        assert!(
            error
                .to_string()
                .contains("after removing short-lived fragments"),
            "{error}"
        );
    }

    #[test]
    fn a_review_without_fragmentation_still_deserializes() {
        let json = r#"{"frames":[],"coverage":[],"usable_coverage":[],"gaps":[],"count":{"count":"unknown","evidence":{"start_ms":0,"end_ms":0},"quality":0.0,"supporting_frames":0}}"#;
        let result: TrackingResult =
            serde_json::from_str(json).expect("an old review deserializes");
        assert!(result.fragmentation.is_none());
    }

    #[test]
    fn short_lived_tracks_are_excluded_from_the_compact_input() {
        let frames = vec![
            frame(0, vec![person(1), person(2)]),
            frame(200, vec![person(2)]),
            frame(400, vec![person(2)]),
        ];
        let result = TrackingResult {
            frames,
            coverage: vec![sportcut_vision::TimeSpan {
                start_ms: 0,
                end_ms: 600,
            }],
            usable_coverage: vec![sportcut_vision::TimeSpan {
                start_ms: 0,
                end_ms: 600,
            }],
            gaps: Vec::new(),
            count: CountAssessment {
                count: ObservedCount::Unknown,
                evidence: sportcut_vision::TimeSpan {
                    start_ms: 0,
                    end_ms: 600,
                },
                quality: 0.0,
                supporting_frames: 0,
            },
            fragmentation: None,
        };
        let artifact =
            TrackArtifact::from_tracking(600, result, provenance()).expect("track artifact");
        assert!(
            artifact
                .input
                .positions
                .iter()
                .all(|position| position.track_id == 2),
            "the one-observation track must not enter the compact input"
        );
        let review = artifact.review.expect("review evidence");
        assert!(
            review
                .frames
                .iter()
                .any(|frame| frame.people.iter().any(|person| person.track_id == Some(1))),
            "the review evidence must retain the short-lived track"
        );
    }
}
