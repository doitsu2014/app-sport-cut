//! The artifact entities: what exists for a match, and where it lives.
//!
//! Everything here is data and rules over data. Reading and writing
//! `manifest.json` is a gateway concern and lives in `sportcut-storage`; these
//! types carry the invariants — which artifact kinds exist, what their states
//! mean, and which derived artifacts become stale when an upstream one is
//! rebuilt — so the media pipeline, the job model, and the storage adapter all
//! agree without any of them depending on each other.
//!
//! The layering rule is enforced by `tools/check-layering.sh`: this crate is the
//! innermost layer and depends on no other workspace crate.

use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::{Result, SportcutError};

/// The kind of derived artifact an entry describes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactKind {
    /// Reduced-resolution analysis proxy.
    Proxy,
    /// Low-bitrate analysis audio track.
    AnalysisAudio,
    /// One sampled frame, as a directory of files.
    Frames,
    /// Court calibration data.
    Calibration,
    /// Per-frame track data.
    Tracks,
    /// Derived rally and rest suggestions.
    RallySuggestions,
    /// A rendered highlight video.
    Export,
}

impl ArtifactKind {
    /// Sub-directory this kind of artifact is written into.
    pub fn directory(self) -> &'static str {
        match self {
            Self::Proxy => "proxy",
            Self::AnalysisAudio => "audio",
            Self::Frames => "frames",
            Self::Calibration => "calibration",
            Self::Tracks => "tracks",
            Self::RallySuggestions => "tracks",
            Self::Export => "export",
        }
    }

    /// Stage label used in progress reporting for this artifact.
    pub fn stage(self) -> &'static str {
        match self {
            Self::Proxy => "proxy",
            Self::AnalysisAudio => "audio",
            Self::Frames => "frames",
            Self::Calibration => "calibration",
            Self::Tracks => "tracks",
            Self::RallySuggestions => "rally_suggestions",
            Self::Export => "export",
        }
    }
}

impl std::fmt::Display for ArtifactKind {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(match self {
            Self::Proxy => "proxy",
            Self::AnalysisAudio => "analysis_audio",
            Self::Frames => "frames",
            Self::Calibration => "calibration",
            Self::Tracks => "tracks",
            Self::RallySuggestions => "rally_suggestions",
            Self::Export => "export",
        })
    }
}

/// Whether an artifact is a finished result or partial output.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactState {
    /// The artifact was produced by a completed stage.
    Final,
    /// The artifact was produced by a stage that was cancelled or interrupted.
    NonFinal,
    /// The artifact is recorded but the file is gone.
    Missing,
}

/// The original recording, referenced in place.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct OriginalMedia {
    /// Absolute path of the original recording on the device.
    pub path: String,
    /// Size in bytes at the time it was last inspected.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub size_bytes: Option<u64>,
    /// Duration in seconds, when known.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub duration_seconds: Option<f64>,
}

impl OriginalMedia {
    /// Reference a recording by path without inspecting it.
    ///
    /// The size is filled in by whoever has already read the file — the
    /// pipeline after probing, or the storage adapter when it initializes a
    /// manifest — so the entity never touches the filesystem.
    pub fn referencing(path: &Path) -> Self {
        Self {
            path: path.to_string_lossy().to_string(),
            size_bytes: None,
            duration_seconds: None,
        }
    }
}

/// One derived artifact.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArtifactEntry {
    /// Kind of artifact.
    pub kind: ArtifactKind,
    /// Path relative to the match directory, using `/` separators.
    pub relative_path: String,
    /// Whether the artifact is finished, partial, or missing.
    pub state: ArtifactState,
    /// Size in bytes when the artifact was produced.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub size_bytes: Option<u64>,
    /// RFC 3339 timestamp of when the artifact was produced.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub produced_at: Option<String>,
}

/// The manifest for one match directory.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArtifactManifest {
    /// Schema version, so later phases can migrate without guessing.
    pub schema_version: u32,
    /// Match identifier; the same value as the directory name.
    pub match_id: String,
    /// The original recording, referenced in place.
    pub original: OriginalMedia,
    /// Derived artifacts produced so far.
    #[serde(default)]
    pub artifacts: Vec<ArtifactEntry>,
    /// RFC 3339 timestamp of the last write.
    pub updated_at: String,
}

/// A short answer to "is this match complete, and what is missing?".
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ManifestSummary {
    /// Match identifier.
    pub match_id: String,
    /// Artifact kinds that are recorded and present with a final state.
    pub complete: Vec<ArtifactKind>,
    /// Artifact kinds that are recorded but whose file is gone.
    pub missing: Vec<ArtifactKind>,
    /// Artifact kinds that exist only as partial, non-final output.
    pub non_final: Vec<ArtifactKind>,
    /// Whether the original recording is still where the manifest says it is.
    pub original_present: bool,
}

impl ArtifactManifest {
    /// Schema version written by this build.
    ///
    /// Version 3 adds [`ArtifactKind::RallySuggestions`]. The bump is not bookkeeping:
    /// serde rejects an unknown enum variant, so a build from before this change
    /// would fail to parse the new kind and report an unreadable manifest.
    /// Raising the version turns that into the explicit "written by a newer
    /// engine" error the storage adapter raises on load instead.
    pub const SCHEMA_VERSION: u32 = 3;

    /// Create an empty manifest for a match.
    pub fn new(match_id: impl Into<String>, original_path: &Path) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            match_id: match_id.into(),
            original: OriginalMedia::referencing(original_path),
            artifacts: Vec::new(),
            updated_at: now_rfc3339(),
        }
    }

    /// Record an artifact, replacing any previous entry of the same kind.
    pub fn record_artifact(
        &mut self,
        kind: ArtifactKind,
        relative_path: impl Into<String>,
        state: ArtifactState,
        size_bytes: Option<u64>,
    ) {
        // Rebuilding upstream media makes court-aware tracks stale. Tracks and
        // analysis audio in turn make rally suggestions stale. The user's
        // accepted rallies live in SQLite and are outside this manifest.
        match kind {
            ArtifactKind::Proxy => {
                self.forget(&[
                    ArtifactKind::Frames,
                    ArtifactKind::Tracks,
                    ArtifactKind::RallySuggestions,
                ]);
            }
            ArtifactKind::Frames => {
                self.forget(&[ArtifactKind::Tracks, ArtifactKind::RallySuggestions]);
            }
            ArtifactKind::Tracks | ArtifactKind::AnalysisAudio => {
                self.forget(&[ArtifactKind::RallySuggestions]);
            }
            _ => {}
        }
        let relative_path = relative_path.into();
        self.artifacts.retain(|entry| entry.kind != kind);
        self.artifacts.push(ArtifactEntry {
            kind,
            relative_path,
            state,
            size_bytes,
            produced_at: Some(now_rfc3339()),
        });
    }

    /// Mark every artifact that is not final as non-final.
    ///
    /// Called when a job is cancelled: partial output stays on disk for
    /// diagnosis but can never be mistaken for a result.
    pub fn mark_all_non_final(&mut self) {
        for entry in &mut self.artifacts {
            if entry.state == ArtifactState::Final {
                entry.state = ArtifactState::NonFinal;
            }
        }
    }

    /// Drop every recorded artifact of the given kinds.
    pub fn forget(&mut self, kinds: &[ArtifactKind]) {
        self.artifacts.retain(|entry| !kinds.contains(&entry.kind));
    }

    /// Find the entry for an artifact kind.
    pub fn entry(&self, kind: ArtifactKind) -> Option<&ArtifactEntry> {
        self.artifacts.iter().find(|entry| entry.kind == kind)
    }
}

/// The directory layout of one match, without touching the filesystem.
///
/// This is the half of a match directory that is pure arithmetic: given a root,
/// where does each file and sub-directory go. The storage adapter owns the
/// other half — creating them, and reading and writing the files inside.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchLayout {
    root: PathBuf,
}

/// File name of the artifact manifest inside a match directory.
pub const MANIFEST_FILE: &str = "manifest.json";

/// File name of the job checkpoint file inside a match directory.
pub const CHECKPOINT_FILE: &str = "checkpoints.json";

/// Sub-directories the engine writes derived artifacts into.
pub const ARTIFACT_DIRS: [&str; 6] = [
    "proxy",
    "audio",
    "frames",
    "calibration",
    "tracks",
    "export",
];

impl MatchLayout {
    /// Wrap a match directory root.
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Root path of this match directory.
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Match identifier, taken from the directory name.
    pub fn match_id(&self) -> String {
        self.root
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_else(|| "match".to_string())
    }

    /// Path of the artifact manifest.
    pub fn manifest_path(&self) -> PathBuf {
        self.root.join(MANIFEST_FILE)
    }

    /// Path of the job checkpoint file.
    pub fn checkpoint_path(&self) -> PathBuf {
        self.root.join(CHECKPOINT_FILE)
    }

    /// Path of one of the artifact sub-directories.
    pub fn artifact_dir(&self, name: &str) -> PathBuf {
        self.root.join(name)
    }

    /// Resolve a manifest-relative artifact path against this directory.
    pub fn resolve(&self, relative: &str) -> PathBuf {
        self.root.join(relative)
    }

    /// Turn an absolute path inside this directory into a relative one.
    pub fn relativize(&self, path: &Path) -> Result<String> {
        path.strip_prefix(&self.root)
            .map(|relative| relative.to_string_lossy().replace('\\', "/"))
            .map_err(|_| {
                SportcutError::Artifact(format!(
                    "{} is outside the match directory {}",
                    path.display(),
                    self.root.display()
                ))
            })
    }
}

/// Current time as an RFC 3339 string, without pulling in a date library.
pub fn now_rfc3339() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}Z", format_unix_seconds(now.as_secs()))
}

/// Format seconds since the Unix epoch as a UTC RFC 3339 timestamp.
fn format_unix_seconds(seconds: u64) -> String {
    // Civil-from-days algorithm (Howard Hinnant), specialized for UTC so the
    // engine has no date/time dependency.
    let days = (seconds / 86_400) as i64;
    let secs_of_day = (seconds % 86_400) as u32;
    let (year, month, day) = civil_from_days(days);
    let hour = secs_of_day / 3600;
    let minute = (secs_of_day % 3600) / 60;
    let second = secs_of_day % 60;
    format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}")
}

fn civil_from_days(days_since_epoch: i64) -> (i64, u32, u32) {
    let z = days_since_epoch + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = if m <= 2 { y + 1 } else { y };
    (year, m as u32, d as u32)
}
