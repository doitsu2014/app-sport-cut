//! The derived rally suggestion set: computed output the user reviews.
//!
//! These are entities, not storage records. They are serialized to
//! `tracks/rally_suggestions.json` by `sportcut-storage`, but the versioning,
//! the input identity, and the rule that a generation matches the inputs it
//! claims are the segmentation model's own rules — so they live here, next to
//! the segmentation they describe.

use serde::{Deserialize, Serialize};
use sportcut_common::{Result, SportcutError};

use crate::{ClassifiedSpan, RallyCandidate, SegmentationConfig, SegmentationResult, SpanKind};

/// Format version of the suggestion file.
pub const RALLY_SUGGESTIONS_SCHEMA_VERSION: u32 = 1;

/// Version of the deterministic segmentation algorithm.
pub const RALLY_SEGMENTER_VERSION: u32 = 1;

/// The exact inputs that make a suggestion generation current.
///
/// Track and audio fingerprints are content identities supplied by their
/// producing stages. A caller must not substitute a path or modification time:
/// either could stay the same while the content changes.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SuggestionInputs {
    /// Duration on the original recording timeline.
    pub duration_ms: i64,
    /// Fingerprint of the consumed player tracks.
    pub tracks_fingerprint: String,
    /// Identity of the calibration used for those tracks.
    pub calibration_id: String,
    /// Fingerprint of analysis audio, or `None` when audio was absent.
    pub audio_fingerprint: Option<String>,
    /// Explicit segmentation thresholds.
    pub config: SegmentationConfig,
}

impl SuggestionInputs {
    /// Validate the identity before it is used to label analysis output.
    pub fn validate(&self) -> Result<()> {
        self.config.validate()?;
        if self.duration_ms <= 0
            || self.tracks_fingerprint.trim().is_empty()
            || self.calibration_id.trim().is_empty()
            || self
                .audio_fingerprint
                .as_ref()
                .is_some_and(|fingerprint| fingerprint.trim().is_empty())
        {
            return Err(SportcutError::InvalidInput(
                "rally suggestions require a duration and non-empty input identities".to_string(),
            ));
        }
        Ok(())
    }
}

/// One candidate with an identity stable for identical inputs.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StoredRallyCandidate {
    /// Stable within the input generation.
    pub id: String,
    /// Proposed span and quality.
    pub candidate: RallyCandidate,
}

/// Versioned, derived output that the user may review.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RallySuggestions {
    /// File format version.
    pub schema_version: u32,
    /// Segmenter implementation version.
    pub algorithm_version: u32,
    /// Identity of all consumed inputs.
    pub inputs: SuggestionInputs,
    /// Stable identity for this input generation.
    pub generation_id: String,
    /// Proposed rallies in recording order.
    pub candidates: Vec<StoredRallyCandidate>,
    /// Complete rally/rest/unknown partition.
    pub timeline: Vec<ClassifiedSpan>,
    /// Fraction of the recording supported by usable tracks.
    pub usable_coverage: f64,
    /// Whether analysis audio was available.
    pub audio_available: bool,
}

impl RallySuggestions {
    /// Attach deterministic identities to a completed segmentation result.
    pub fn from_result(inputs: SuggestionInputs, result: SegmentationResult) -> Result<Self> {
        inputs.validate()?;
        if result.audio_available != inputs.audio_fingerprint.is_some() {
            return Err(SportcutError::InvalidInput(
                "rally suggestion audio identity does not match the analysis result".to_string(),
            ));
        }
        if result.timeline.first().map(|span| span.time.start_ms) != Some(0)
            || result.timeline.last().map(|span| span.time.end_ms) != Some(inputs.duration_ms)
            || !unit(result.usable_coverage)
        {
            return Err(SportcutError::InvalidInput(
                "rally suggestions do not cover the recording timeline".to_string(),
            ));
        }
        let generation_id = generation_id(&inputs)?;
        let candidates = result
            .rallies
            .into_iter()
            .enumerate()
            .map(|(index, candidate)| StoredRallyCandidate {
                id: format!("{generation_id}-{index}"),
                candidate,
            })
            .collect();
        Ok(Self {
            schema_version: RALLY_SUGGESTIONS_SCHEMA_VERSION,
            algorithm_version: RALLY_SEGMENTER_VERSION,
            inputs,
            generation_id,
            candidates,
            timeline: result.timeline,
            usable_coverage: result.usable_coverage,
            audio_available: result.audio_available,
        })
    }

    /// Check that the set is internally consistent with the inputs it claims.
    ///
    /// A set that fails this is never presented as a result: it was written by a
    /// different generation, or partially written.
    pub fn validate(&self) -> Result<()> {
        self.inputs.validate()?;
        if self.schema_version != RALLY_SUGGESTIONS_SCHEMA_VERSION
            || self.algorithm_version != RALLY_SEGMENTER_VERSION
            || self.generation_id != generation_id(&self.inputs)?
        {
            return Err(SportcutError::Artifact(
                "rally suggestions have an unsupported version or input identity".to_string(),
            ));
        }
        if !unit(self.usable_coverage)
            || self.audio_available != self.inputs.audio_fingerprint.is_some()
        {
            return Err(SportcutError::Artifact(
                "rally suggestions have inconsistent signal availability".to_string(),
            ));
        }
        let mut next_start = 0;
        for span in &self.timeline {
            if span.time.start_ms != next_start || span.time.end_ms <= next_start {
                return Err(SportcutError::Artifact(
                    "rally suggestion intervals do not partition the recording".to_string(),
                ));
            }
            next_start = span.time.end_ms;
        }
        if next_start != self.inputs.duration_ms {
            return Err(SportcutError::Artifact(
                "rally suggestion intervals do not cover the recording".to_string(),
            ));
        }
        let rally_spans = self
            .timeline
            .iter()
            .filter(|span| span.kind == SpanKind::Rally);
        if self.candidates.len() != rally_spans.clone().count() {
            return Err(SportcutError::Artifact(
                "rally candidate count does not match the activity timeline".to_string(),
            ));
        }
        for (index, (candidate, span)) in self.candidates.iter().zip(rally_spans).enumerate() {
            if candidate.id != format!("{}-{index}", self.generation_id)
                || candidate.candidate.time != span.time
                || !unit(candidate.candidate.quality)
                || candidate.candidate.audio_available != self.audio_available
            {
                return Err(SportcutError::Artifact(
                    "rally candidate does not match its generation or timeline".to_string(),
                ));
            }
        }
        Ok(())
    }
}

fn generation_id(inputs: &SuggestionInputs) -> Result<String> {
    let bytes = serde_json::to_vec(&(RALLY_SEGMENTER_VERSION, inputs)).map_err(|error| {
        SportcutError::Artifact(format!(
            "could not identify rally suggestion inputs: {error}"
        ))
    })?;
    // FNV-1a is a reproducible content label, not a security boundary.
    let hash = bytes.iter().fold(0xcbf29ce484222325_u64, |hash, byte| {
        (hash ^ u64::from(*byte)).wrapping_mul(0x100000001b3)
    });
    Ok(format!("rally-{hash:016x}"))
}

fn unit(value: f64) -> bool {
    value.is_finite() && (0.0..=1.0).contains(&value)
}
