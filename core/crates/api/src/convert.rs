//! Conversions from engine types to the frozen bridge contract.

use std::path::Path;

use sportcut_jobs::{JobProgress, JobState, JobStatus};
use sportcut_media::{MediaMetadata, Orientation};
use sportcut_storage::{ArtifactManifest, ArtifactState};

use crate::dto::{
    ArtifactDto, ArtifactManifestDto, ArtifactStateDto, JobProgressDto, JobStateDto, JobStatusDto,
    MediaMetadataDto, OrientationDto,
};

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
            missing_kinds: summary.missing.iter().map(ToString::to_string).collect(),
            original_present: summary.original_present,
        }
    }
}
