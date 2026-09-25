//! Conversions from engine types to the frozen bridge contract.

use std::path::Path;

use sportcut_common::{Result, SportcutError};
use sportcut_court::{CalibrationSegment, CourtCalibration, CourtOrientation, ImagePoint};
use sportcut_jobs::{JobProgress, JobState, JobStatus};
use sportcut_media::{MediaMetadata, Orientation, REBUILDABLE_KINDS};
use sportcut_rally::{SegmentationConfig, SpanKind};
use sportcut_storage::{ArtifactManifest, ArtifactState, RallySuggestions};
use sportcut_vision::{CandidateDecision, CourtCandidateConfig, ObservedCount, TrackingConfig};

use crate::dto::{
    ArtifactDto, ArtifactManifestDto, ArtifactStateDto, CalibrationSegmentDto, CourtCalibrationDto,
    CourtCornerDto, CourtGeometryDto, CourtOrientationDto, JobProgressDto, JobStateDto,
    JobStatusDto, MediaMetadataDto, ObservedPlayerCountDto, OrientationDto, PersonSelectionDto,
    PlayerCourtSideDto, PlayerGapDto, PlayerObservationDto, PlayerTrackFrameDto,
    PlayerTrackingConfigDto, PlayerTracksDto, RallyActivitySpanDto, RallySegmentationConfigDto,
    RallySuggestionDto, RallySuggestionsDto, TrackIntervalDto,
};
use crate::track_artifact::TrackArtifact;

impl PlayerTracksDto {
    pub(crate) fn from_artifact_window(
        artifact: &TrackArtifact,
        start_ms: i64,
        end_ms: i64,
    ) -> Result<Self> {
        let review = artifact.review.as_ref().ok_or_else(|| {
            SportcutError::Artifact("player track review evidence is missing".to_string())
        })?;
        let mut frames = Vec::new();
        for frame in &review.frames {
            if frame.timestamp_ms < start_ms || frame.timestamp_ms >= end_ms {
                continue;
            }
            if frame.width == 0 || frame.height == 0 {
                return Err(SportcutError::Artifact(
                    "player track frame dimensions are zero".to_string(),
                ));
            }
            let width = f64::from(frame.width);
            let height = f64::from(frame.height);
            let people = frame
                .people
                .iter()
                .map(|person| {
                    let box_in_frame = person.candidate.detection.bbox;
                    let ground = person.candidate.ground_point;
                    let court = person.candidate.court_point;
                    PlayerObservationDto {
                        track_id: person.track_id,
                        confidence: person.candidate.detection.confidence,
                        box_x: f64::from(box_in_frame.x) / width,
                        box_y: f64::from(box_in_frame.y) / height,
                        box_width: f64::from(box_in_frame.width) / width,
                        box_height: f64::from(box_in_frame.height) / height,
                        ground_x: ground.map(|point| point.x),
                        ground_y: ground.map(|point| point.y),
                        court_u: court.map(|point| point.u),
                        court_v: court.map(|point| point.v),
                        side: match person.candidate.side {
                            Some(sportcut_court::CourtSide::First) => PlayerCourtSideDto::First,
                            Some(sportcut_court::CourtSide::Second) => PlayerCourtSideDto::Second,
                            None => PlayerCourtSideDto::Unknown,
                        },
                        selection: match person.candidate.decision {
                            CandidateDecision::OnCourt => PersonSelectionDto::OnCourt,
                            CandidateDecision::LowConfidence => PersonSelectionDto::LowConfidence,
                            CandidateDecision::InvalidBox => PersonSelectionDto::InvalidBox,
                            CandidateDecision::MissingCalibration => {
                                PersonSelectionDto::MissingCalibration
                            }
                            CandidateDecision::ProjectionFailed => {
                                PersonSelectionDto::ProjectionFailed
                            }
                            CandidateDecision::Borderline => PersonSelectionDto::Borderline,
                            CandidateDecision::OffCourt => PersonSelectionDto::OffCourt,
                        },
                        association_ambiguous: person.association_ambiguous,
                    }
                })
                .collect();
            frames.push(PlayerTrackFrameDto {
                timestamp_seconds: frame.timestamp_ms as f64 / 1000.0,
                people,
            });
        }
        Ok(Self {
            schema_version: artifact.schema_version,
            model_id: artifact
                .provenance
                .as_ref()
                .map_or_else(|| "unknown".to_string(), |value| value.model_id.clone()),
            count: match review.count.count {
                ObservedCount::Two => ObservedPlayerCountDto::Two,
                ObservedCount::Four => ObservedPlayerCountDto::Four,
                ObservedCount::Unknown => ObservedPlayerCountDto::Unknown,
            },
            count_quality: review.count.quality,
            count_evidence: TrackIntervalDto {
                start_seconds: review.count.evidence.start_ms as f64 / 1000.0,
                end_seconds: review.count.evidence.end_ms as f64 / 1000.0,
            },
            coverage: review
                .coverage
                .iter()
                .map(|span| TrackIntervalDto {
                    start_seconds: span.start_ms as f64 / 1000.0,
                    end_seconds: span.end_ms as f64 / 1000.0,
                })
                .collect(),
            usable_coverage: review
                .usable_coverage
                .iter()
                .map(|span| TrackIntervalDto {
                    start_seconds: span.start_ms as f64 / 1000.0,
                    end_seconds: span.end_ms as f64 / 1000.0,
                })
                .collect(),
            gaps: review
                .gaps
                .iter()
                .filter(|gap| gap.time.end_ms > start_ms && gap.time.start_ms < end_ms)
                .map(|gap| PlayerGapDto {
                    track_id: gap.track_id,
                    time: TrackIntervalDto {
                        start_seconds: gap.time.start_ms as f64 / 1000.0,
                        end_seconds: gap.time.end_ms as f64 / 1000.0,
                    },
                })
                .collect(),
            frames,
        })
    }
}

impl From<&PlayerTrackingConfigDto> for TrackingConfig {
    fn from(config: &PlayerTrackingConfigDto) -> Self {
        Self {
            court: CourtCandidateConfig {
                min_confidence: config.min_confidence,
                court_margin: config.court_margin,
                net_margin: config.net_margin,
            },
            max_track_gap_ms: config.max_track_gap_ms,
            max_frame_gap_ms: config.max_frame_gap_ms,
            max_ground_speed_per_second: config.max_ground_speed_per_second,
            ambiguity_margin: config.ambiguity_margin,
            min_track_observations: config.min_track_observations as usize,
            min_count_frames: config.min_count_frames as usize,
            min_count_fraction: config.min_count_fraction,
        }
    }
}

impl From<&RallySegmentationConfigDto> for SegmentationConfig {
    fn from(config: &RallySegmentationConfigDto) -> Self {
        Self {
            bin_ms: config.bin_ms,
            max_track_gap_ms: config.max_track_gap_ms,
            enter_motion_per_second: config.enter_motion_per_second,
            exit_motion_per_second: config.exit_motion_per_second,
            audio_intensity_threshold: config.audio_intensity_threshold,
            min_rally_ms: config.min_rally_ms,
            min_rest_ms: config.min_rest_ms,
            min_usable_coverage: config.min_usable_coverage,
        }
    }
}

impl From<&RallySuggestions> for RallySuggestionsDto {
    fn from(suggestions: &RallySuggestions) -> Self {
        Self {
            schema_version: suggestions.schema_version,
            algorithm_version: suggestions.algorithm_version,
            generation_id: suggestions.generation_id.clone(),
            candidates: suggestions
                .candidates
                .iter()
                .map(|stored| RallySuggestionDto {
                    id: stored.id.clone(),
                    start_seconds: stored.candidate.time.start_ms as f64 / 1000.0,
                    end_seconds: stored.candidate.time.end_ms as f64 / 1000.0,
                    quality: stored.candidate.quality,
                    audio_available: stored.candidate.audio_available,
                })
                .collect(),
            timeline: suggestions
                .timeline
                .iter()
                .map(|span| RallyActivitySpanDto {
                    start_seconds: span.time.start_ms as f64 / 1000.0,
                    end_seconds: span.time.end_ms as f64 / 1000.0,
                    kind: match span.kind {
                        SpanKind::Rally => "rally",
                        SpanKind::Rest => "rest",
                        SpanKind::Unknown => "unknown",
                    }
                    .to_string(),
                })
                .collect(),
            usable_coverage: suggestions.usable_coverage,
            audio_available: suggestions.audio_available,
        }
    }
}

impl From<&MediaMetadata> for MediaMetadataDto {
    fn from(metadata: &MediaMetadata) -> Self {
        Self {
            path: metadata.path.clone(),
            duration_seconds: metadata.duration_seconds,
            frame_rate: metadata.frame_rate,
            width: metadata.width,
            height: metadata.height,
            rotation_degrees: metadata.rotation_degrees,
            orientation: match metadata.orientation() {
                Orientation::Landscape => OrientationDto::Landscape,
                Orientation::Portrait => OrientationDto::Portrait,
                Orientation::UpsideDown => OrientationDto::UpsideDown,
                Orientation::PortraitReversed => OrientationDto::PortraitReversed,
                Orientation::Unknown => OrientationDto::Unknown,
            },
            has_audio: metadata.has_audio,
            size_bytes: metadata.size_bytes,
        }
    }
}

impl From<JobState> for JobStateDto {
    fn from(state: JobState) -> Self {
        match state {
            JobState::Pending => Self::Pending,
            JobState::Running => Self::Running,
            JobState::Completed => Self::Completed,
            JobState::Cancelled => Self::Cancelled,
            JobState::Failed => Self::Failed,
        }
    }
}

impl From<&JobProgress> for JobProgressDto {
    fn from(progress: &JobProgress) -> Self {
        Self {
            stage: progress.stage.clone(),
            value: progress.value,
            message: progress.message.clone(),
        }
    }
}

impl From<&JobStatus> for JobStatusDto {
    fn from(status: &JobStatus) -> Self {
        Self {
            job_id: status.job_id.to_string(),
            match_id: status.match_id.clone(),
            state: JobStateDto::from(status.state),
            stage: status.stage.clone(),
            progress: status.progress.as_ref().map(JobProgressDto::from),
            error: status.error.clone(),
            completed_stages: status.completed_stages.clone(),
        }
    }
}

impl From<ArtifactState> for ArtifactStateDto {
    fn from(state: ArtifactState) -> Self {
        match state {
            ArtifactState::Final => Self::Final,
            ArtifactState::NonFinal => Self::NonFinal,
            ArtifactState::Missing => Self::Missing,
        }
    }
}

impl ArtifactManifestDto {
    /// Build the client view of a manifest, resolving which artifacts are
    /// missing against the match directory on disk.
    pub fn from_manifest(manifest: &ArtifactManifest, match_root: &Path) -> Self {
        let summary = manifest.summarize(match_root);
        let missing_kinds: Vec<String> = summary.missing.iter().map(ToString::to_string).collect();
        let not_rebuildable_kinds = summary
            .missing
            .iter()
            .filter(|kind| !REBUILDABLE_KINDS.contains(kind))
            .map(ToString::to_string)
            .collect();
        Self {
            match_id: manifest.match_id.clone(),
            original_path: manifest.original.path.clone(),
            artifacts: manifest
                .artifacts
                .iter()
                .map(|entry| ArtifactDto {
                    kind: entry.kind.to_string(),
                    relative_path: entry.relative_path.clone(),
                    state: match entry.state {
                        ArtifactState::Final if !match_root.join(&entry.relative_path).exists() => {
                            ArtifactStateDto::Missing
                        }
                        state => ArtifactStateDto::from(state),
                    },
                    size_bytes: entry.size_bytes,
                })
                .collect(),
            missing_kinds,
            not_rebuildable_kinds,
            original_present: summary.original_present,
        }
    }
}

impl From<&ImagePoint> for CourtCornerDto {
    fn from(point: &ImagePoint) -> Self {
        Self {
            x: point.x,
            y: point.y,
        }
    }
}

impl From<&CourtOrientation> for CourtOrientationDto {
    fn from(orientation: &CourtOrientation) -> Self {
        match orientation {
            CourtOrientation::Away => Self::Away,
            CourtOrientation::Across => Self::Across,
        }
    }
}

impl From<&CalibrationSegment> for CalibrationSegmentDto {
    fn from(segment: &CalibrationSegment) -> Self {
        Self {
            from_ms: segment.from_ms,
            corners: segment.corners.iter().map(CourtCornerDto::from).collect(),
            orientation: CourtOrientationDto::from(&segment.orientation),
        }
    }
}

impl From<&CourtCalibration> for CourtCalibrationDto {
    fn from(calibration: &CourtCalibration) -> Self {
        Self {
            schema_version: calibration.schema_version,
            segments: calibration
                .segments
                .iter()
                .map(CalibrationSegmentDto::from)
                .collect(),
        }
    }
}

impl CourtGeometryDto {
    /// Derive the geometry of one segment: both directions of the mapping, and
    /// the outline and net the application draws.
    pub fn from_segment(segment: &CalibrationSegment) -> Result<Self> {
        let mapping = segment.mapping()?;
        let outline = segment.outline()?;
        Ok(Self {
            image_to_court: flatten(&mapping.image_to_court),
            court_to_image: flatten(&mapping.court_to_image),
            corners: outline.corners.iter().map(CourtCornerDto::from).collect(),
            net: outline.net.iter().map(CourtCornerDto::from).collect(),
        })
    }
}

impl TryFrom<&CourtCornerDto> for ImagePoint {
    type Error = SportcutError;

    fn try_from(corner: &CourtCornerDto) -> Result<Self> {
        if !corner.x.is_finite() || !corner.y.is_finite() {
            return Err(SportcutError::InvalidInput(format!(
                "court calibration: corner ({}, {}) is not a number",
                corner.x, corner.y
            )));
        }
        Ok(Self::new(corner.x, corner.y))
    }
}

impl From<CourtOrientationDto> for CourtOrientation {
    fn from(orientation: CourtOrientationDto) -> Self {
        match orientation {
            CourtOrientationDto::Away => Self::Away,
            CourtOrientationDto::Across => Self::Across,
        }
    }
}

impl TryFrom<&CalibrationSegmentDto> for CalibrationSegment {
    type Error = SportcutError;

    fn try_from(segment: &CalibrationSegmentDto) -> Result<Self> {
        if segment.corners.len() != 4 {
            return Err(SportcutError::InvalidInput(format!(
                "court calibration: a segment needs four corners, got {}",
                segment.corners.len()
            )));
        }
        let mut corners = [ImagePoint::new(0.0, 0.0); 4];
        for (slot, corner) in corners.iter_mut().zip(segment.corners.iter()) {
            *slot = ImagePoint::try_from(corner)?;
        }
        Ok(Self {
            from_ms: segment.from_ms,
            corners,
            orientation: segment.orientation.into(),
        })
    }
}

impl TryFrom<&CourtCalibrationDto> for CourtCalibration {
    type Error = SportcutError;

    fn try_from(calibration: &CourtCalibrationDto) -> Result<Self> {
        let segments = calibration
            .segments
            .iter()
            .map(CalibrationSegment::try_from)
            .collect::<Result<Vec<_>>>()?;
        Ok(Self {
            schema_version: calibration.schema_version,
            segments,
        })
    }
}

/// Flatten a row-major matrix into the nine values the bridge carries.
fn flatten(matrix: &[[f64; 3]; 3]) -> Vec<f64> {
    matrix.iter().flatten().copied().collect()
}
