//! The per-match manifest.
//!
//! The manifest is the engine's record of what exists for a match. It refers to
//! the original recording in place and records every derived artifact with
//! enough state to answer two questions the application asks constantly:
//!
//! * which derived artifacts are missing, so they can be regenerated without
//!   re-importing the match; and
//! * whether an artifact is final, so a cancelled job's partial output is never
//!   presented as a result.

use std::path::Path;

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};

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
    /// Version 2 added [`ArtifactKind::Export`]. The bump is not bookkeeping:
    /// serde rejects an unknown enum variant, so a build from before this change
    /// would fail to parse `"kind": "export"` and report an unreadable manifest.
    /// Raising the version turns that into the explicit "written by a newer
    /// engine" error below instead.
    pub const SCHEMA_VERSION: u32 = 2;

    /// Create an empty manifest for a match.
    pub fn new(match_id: impl Into<String>, original: &Path) -> Self {
        let match_id = match_id.into();
        Self {
            schema_version: Self::SCHEMA_VERSION,
            match_id,
            original: OriginalMedia {
                path: original.to_string_lossy().to_string(),
                size_bytes: std::fs::metadata(original).ok().map(|meta| meta.len()),
                duration_seconds: None,
            },
            artifacts: Vec::new(),
            updated_at: now_rfc3339(),
        }
    }

    /// Read a manifest from disk.
    pub fn load(path: &Path) -> Result<Self> {
        let bytes = std::fs::read(path).map_err(|e| SportcutError::io(path, e))?;
        let manifest: Self = serde_json::from_slice(&bytes).map_err(|e| {
            SportcutError::Artifact(format!(
                "{} is not a readable manifest: {e}",
                path.display()
            ))
        })?;
        if manifest.schema_version > Self::SCHEMA_VERSION {
            return Err(SportcutError::Artifact(format!(
                "{} was written by a newer engine (schema {} > {})",
                path.display(),
                manifest.schema_version,
                Self::SCHEMA_VERSION
            )));
        }
        Ok(manifest)
    }

    /// Write the manifest to disk, updating `updated_at`.
    pub fn save(&mut self, path: &Path) -> Result<()> {
        self.updated_at = now_rfc3339();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| SportcutError::io(parent, e))?;
        }
        let json = serde_json::to_vec_pretty(self)
            .map_err(|e| SportcutError::Artifact(format!("could not serialize manifest: {e}")))?;
        std::fs::write(path, json).map_err(|e| SportcutError::io(path, e))?;
        Ok(())
    }

    /// Record an artifact, replacing any previous entry of the same kind.
    pub fn record_artifact(
        &mut self,
        kind: ArtifactKind,
        relative_path: impl Into<String>,
        state: ArtifactState,
        size_bytes: Option<u64>,
    ) {
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

    /// Summarize completeness, checking the filesystem for each artifact.
    pub fn summarize(&self, root: &Path) -> ManifestSummary {
        let mut summary = ManifestSummary {
            match_id: self.match_id.clone(),
            complete: Vec::new(),
            missing: Vec::new(),
            non_final: Vec::new(),
            original_present: Path::new(&self.original.path).is_file(),
        };

        for entry in &self.artifacts {
            let path = root.join(&entry.relative_path);
            if !path.exists() {
                summary.missing.push(entry.kind);
            } else {
                match entry.state {
                    ArtifactState::Final | ArtifactState::Missing => {
                        summary.complete.push(entry.kind);
                    }
                    ArtifactState::NonFinal => summary.non_final.push(entry.kind),
                }
            }
        }

        summary
    }

    /// Artifact kinds the manifest says exist but whose files are gone.
    ///
    /// This is what makes derived artifacts regenerable: the application can
    /// ask for exactly these to be rebuilt without re-importing the match.
    pub fn missing_artifacts(&self, root: &Path) -> Vec<ArtifactKind> {
        self.artifacts
            .iter()
            .filter(|entry| !root.join(&entry.relative_path).exists())
            .map(|entry| entry.kind)
            .collect()
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
