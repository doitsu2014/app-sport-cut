//! Hand-written ground truth and the manifest that lists labeled clips.

use std::collections::BTreeSet;

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};
use sportcut_rally::TimeSpan;

/// Format version of a clip label file.
pub const LABELS_SCHEMA_VERSION: u32 = 1;

/// Format version of a manifest file.
pub const MANIFEST_SCHEMA_VERSION: u32 = 1;

/// One labeled rally: serve contact to the moment the shuttle is dead.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LabeledRally {
    /// Inclusive start, in milliseconds on the original recording.
    pub start_ms: i64,
    /// Exclusive end, in milliseconds on the original recording.
    pub end_ms: i64,
}

impl LabeledRally {
    /// The same interval as an engine time span.
    pub fn span(self) -> TimeSpan {
        TimeSpan {
            start_ms: self.start_ms,
            end_ms: self.end_ms,
        }
    }
}

/// Ground truth for one recording.
///
/// Unknown fields are rejected so a typo in a hand-edited file is reported
/// instead of silently ignored.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClipLabels {
    /// File format version.
    pub schema_version: u32,
    /// Identity of the clip within a manifest.
    pub clip_id: String,
    /// Length of the original recording.
    pub duration_ms: i64,
    /// Players on court: 2 for singles, 4 for doubles.
    pub players: u8,
    /// Whether the recording follows the recording guidelines.
    pub clean: bool,
    /// Every rally in the recording, in order and without overlap.
    pub rallies: Vec<LabeledRally>,
    /// Free-text context about the footage. Never personal names.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
}

impl ClipLabels {
    /// Reject labels that cannot be scored, naming the clip and the field.
    pub fn validate(&self) -> Result<()> {
        let clip = self.clip_id.trim();
        if clip.is_empty() {
            return Err(invalid("labels: clip_id must not be empty".to_string()));
        }
        if self.schema_version != LABELS_SCHEMA_VERSION {
            return Err(invalid(format!(
                "labels {clip}: schema_version {} is not supported (expected {LABELS_SCHEMA_VERSION})",
                self.schema_version
            )));
        }
        if self.duration_ms <= 0 {
            return Err(invalid(format!(
                "labels {clip}: duration_ms must be positive"
            )));
        }
        if self.players != 2 && self.players != 4 {
            return Err(invalid(format!(
                "labels {clip}: players is {}, expected 2 or 4",
                self.players
            )));
        }
        let mut previous_end = 0;
        for (index, rally) in self.rallies.iter().enumerate() {
            if rally.end_ms <= rally.start_ms {
                return Err(invalid(format!(
                    "labels {clip}: rallies[{index}] ends at or before it starts"
                )));
            }
            if rally.start_ms < 0 || rally.end_ms > self.duration_ms {
                return Err(invalid(format!(
                    "labels {clip}: rallies[{index}] lies outside 0..{} ms",
                    self.duration_ms
                )));
            }
            if rally.start_ms < previous_end {
                return Err(invalid(format!(
                    "labels {clip}: rallies[{index}] overlaps or precedes the previous rally"
                )));
            }
            previous_end = rally.end_ms;
        }
        Ok(())
    }

    /// Labeled rallies as engine time spans.
    pub fn rally_spans(&self) -> Vec<TimeSpan> {
        self.rallies.iter().map(|rally| rally.span()).collect()
    }
}

/// One labeled clip and where its engine output lives.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ManifestEntry {
    /// Must equal the `clip_id` inside the label file.
    pub clip_id: String,
    /// Label file, relative to the manifest or absolute.
    pub labels: String,
    /// Match directory holding `tracks/`, relative to the manifest or absolute.
    pub match_dir: String,
}

/// A set of labeled clips scored together.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    /// File format version.
    pub schema_version: u32,
    /// Clips to score.
    pub clips: Vec<ManifestEntry>,
}

impl Manifest {
    /// Reject a manifest with an unknown version, no clips, or ambiguous ids.
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != MANIFEST_SCHEMA_VERSION {
            return Err(invalid(format!(
                "manifest: schema_version {} is not supported (expected {MANIFEST_SCHEMA_VERSION})",
                self.schema_version
            )));
        }
        if self.clips.is_empty() {
            return Err(invalid("manifest: clips must not be empty".to_string()));
        }
        let mut seen = BTreeSet::new();
        for (index, entry) in self.clips.iter().enumerate() {
            let clip = entry.clip_id.trim();
            if clip.is_empty() {
                return Err(invalid(format!(
                    "manifest: clips[{index}].clip_id is empty"
                )));
            }
            if !seen.insert(clip) {
                return Err(invalid(format!("manifest: clip_id {clip} appears twice")));
            }
        }
        Ok(())
    }
}

fn invalid(message: String) -> SportcutError {
    SportcutError::InvalidInput(message)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn labels() -> ClipLabels {
        ClipLabels {
            schema_version: LABELS_SCHEMA_VERSION,
            clip_id: "c1".to_string(),
            duration_ms: 60_000,
            players: 4,
            clean: true,
            rallies: vec![
                LabeledRally {
                    start_ms: 1_000,
                    end_ms: 5_000,
                },
                LabeledRally {
                    start_ms: 5_000,
                    end_ms: 9_000,
                },
            ],
            notes: None,
        }
    }

    fn message(labels: &ClipLabels) -> String {
        labels.validate().unwrap_err().to_string()
    }

    #[test]
    fn accepts_touching_sorted_rallies() {
        assert!(labels().validate().is_ok());
    }

    #[test]
    fn rejects_bad_fields_by_name() {
        let mut bad = labels();
        bad.players = 3;
        assert!(message(&bad).contains("players is 3"));

        let mut bad = labels();
        bad.schema_version = 2;
        assert!(message(&bad).contains("schema_version 2"));

        let mut bad = labels();
        bad.rallies[1].start_ms = 4_000;
        assert!(message(&bad).contains("rallies[1] overlaps"));

        let mut bad = labels();
        bad.rallies[0].end_ms = 1_000;
        assert!(message(&bad).contains("rallies[0] ends"));

        let mut bad = labels();
        bad.rallies[1].end_ms = 61_000;
        assert!(message(&bad).contains("outside"));

        let mut bad = labels();
        bad.clip_id = " ".to_string();
        assert!(message(&bad).contains("clip_id"));
    }

    #[test]
    fn rejects_unknown_label_fields() {
        let json = r#"{"schema_version":1,"clip_id":"c","duration_ms":1,"players":2,
            "clean":true,"rallies":[],"rallys":[]}"#;
        assert!(serde_json::from_str::<ClipLabels>(json).is_err());
    }

    #[test]
    fn manifest_rejects_duplicates_and_empty() {
        let entry = ManifestEntry {
            clip_id: "c1".to_string(),
            labels: "c1.labels.json".to_string(),
            match_dir: "c1".to_string(),
        };
        let manifest = Manifest {
            schema_version: MANIFEST_SCHEMA_VERSION,
            clips: vec![entry.clone(), entry],
        };
        assert!(manifest
            .validate()
            .unwrap_err()
            .to_string()
            .contains("twice"));

        let empty = Manifest {
            schema_version: MANIFEST_SCHEMA_VERSION,
            clips: Vec::new(),
        };
        assert!(empty.validate().is_err());
    }
}
