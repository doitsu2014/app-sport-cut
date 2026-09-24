//! Motion-first rally and rest segmentation over a future court-aware track stream.
//!
//! This crate accepts positions on the unit-square court and explicit coverage
//! intervals. It does not detect people, decode media, or choose thresholds for
//! a particular camera. The caller supplies those inputs and a configuration
//! selected from representative footage.

#![forbid(unsafe_code)]

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use sportcut_common::{CancelToken, Result, SportcutError};

/// A half-open interval on the original recording timeline.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct TimeSpan {
    /// Inclusive start, in milliseconds.
    pub start_ms: i64,
    /// Exclusive end, in milliseconds.
    pub end_ms: i64,
}

impl TimeSpan {
    fn contains(self, timestamp_ms: i64) -> bool {
        self.start_ms <= timestamp_ms && timestamp_ms < self.end_ms
    }
}

/// One tracked player's position on the normalized court plane.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TrackPosition {
    /// Timestamp on the original recording timeline.
    pub timestamp_ms: i64,
    /// Stable identity within this track generation.
    pub track_id: u64,
    /// Position across the court, in `0.0..=1.0`.
    pub u: f64,
    /// Position from the near edge to the far edge, in `0.0..=1.0`.
    pub v: f64,
}

/// Normalized intensity of an analysis-audio sample.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct AudioIntensity {
    /// Timestamp on the original recording timeline.
    pub timestamp_ms: i64,
    /// Relative intensity, in `0.0..=1.0`.
    pub value: f64,
}

/// Inputs supplied by the future tracking adapter.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SegmentationInput {
    /// Length of the original recording.
    pub duration_ms: i64,
    /// Identity of the calibration used to produce the positions.
    pub calibration_id: String,
    /// Intervals where the tracker attempted to observe the court.
    pub coverage: Vec<TimeSpan>,
    /// Court positions, ordered by timestamp.
    pub positions: Vec<TrackPosition>,
    /// Optional normalized analysis-audio intensities.
    pub audio: Option<Vec<AudioIntensity>>,
}

/// Explicit, footage-tuned parameters of the deterministic segmenter.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SegmentationConfig {
    /// Width of one activity bin in milliseconds.
    pub bin_ms: i64,
    /// Largest gap between two positions that can measure movement.
    pub max_track_gap_ms: i64,
    /// Motion in normalized court units per second needed to enter a rally.
    pub enter_motion_per_second: f64,
    /// Motion needed to stay in a rally, and the minimum for audio support.
    pub exit_motion_per_second: f64,
    /// Minimum audio intensity that may support weak motion.
    pub audio_intensity_threshold: f64,
    /// A rally shorter than this is treated as rest.
    pub min_rally_ms: i64,
    /// A rest shorter than this is joined when flanked by rallies.
    pub min_rest_ms: i64,
    /// Minimum fraction of the recording with usable track pairs.
    pub min_usable_coverage: f64,
}

impl SegmentationConfig {
    /// Validate parameters before any analysis work begins.
    pub fn validate(self) -> Result<()> {
        if self.bin_ms <= 0
            || self.max_track_gap_ms < self.bin_ms
            || self.min_rally_ms <= 0
            || self.min_rest_ms < 0
        {
            return Err(invalid(
                "segmentation durations must be positive and track gaps must cover a bin",
            ));
        }
        if !self.enter_motion_per_second.is_finite()
            || !self.exit_motion_per_second.is_finite()
            || self.exit_motion_per_second <= 0.0
            || self.enter_motion_per_second < self.exit_motion_per_second
        {
            return Err(invalid(
                "motion thresholds must be finite, positive, and ordered",
            ));
        }
        if !unit(self.audio_intensity_threshold) || !unit(self.min_usable_coverage) {
            return Err(invalid(
                "audio and coverage thresholds must be between zero and one",
            ));
        }
        Ok(())
    }
}

/// Classification of an interval.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SpanKind {
    /// Likely active play.
    Rally,
    /// Tracked inactivity.
    Rest,
    /// Tracking coverage is insufficient to classify this interval.
    Unknown,
}

/// One classified interval of the recording.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClassifiedSpan {
    /// Position on the original recording timeline.
    pub time: TimeSpan,
    /// Proposed activity state.
    pub kind: SpanKind,
}

/// A proposed rally with a heuristic quality indicator, not a probability.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct RallyCandidate {
    /// Position on the original recording timeline.
    pub time: TimeSpan,
    /// Bounded `0.0..=1.0` measure of motion and track support.
    pub quality: f64,
    /// Whether analysis audio was supplied at all.
    pub audio_available: bool,
}

/// Complete deterministic result, including inactive and unknown spans.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SegmentationResult {
    /// Proposed rallies in recording order.
    pub rallies: Vec<RallyCandidate>,
    /// Partition of the whole recording into rally, rest, and unknown spans.
    pub timeline: Vec<ClassifiedSpan>,
    /// Fraction of the recording supported by track pairs.
    pub usable_coverage: f64,
    /// Whether analysis audio was supplied.
    pub audio_available: bool,
}

#[derive(Debug, Clone, Copy, Default)]
struct Bin {
    motion: f64,
    pairs: u32,
    audio: f64,
}

/// Propose active intervals from player motion and optional supporting audio.
///
/// No result is returned when tracks cannot distinguish activity from absence
/// of observations. In particular, an empty candidate list is only meaningful
/// after the required track coverage has been checked.
pub fn segment(
    input: &SegmentationInput,
    config: SegmentationConfig,
) -> Result<SegmentationResult> {
    segment_with_cancel(input, config, &CancelToken::new())
}

/// Segment while checking for cancellation between bounded work units.
pub fn segment_with_cancel(
    input: &SegmentationInput,
    config: SegmentationConfig,
    cancel: &CancelToken,
) -> Result<SegmentationResult> {
    config.validate()?;
    validate_input(input)?;
    cancel.check()?;

    const MAX_BINS: i64 = 1_000_000;
    let bin_count = (input.duration_ms - 1) / config.bin_ms + 1;
    if bin_count > MAX_BINS {
        return Err(invalid("requested analysis grid is too large"));
    }
    let mut bins = vec![Bin::default(); bin_count as usize];
    let mut previous = HashMap::<u64, TrackPosition>::new();

    for position in &input.positions {
        cancel.check()?;
        if let Some(before) = previous.insert(position.track_id, *position) {
            let gap_ms = position.timestamp_ms - before.timestamp_ms;
            if gap_ms <= 0 || gap_ms > config.max_track_gap_ms {
                continue;
            }
            let distance =
                ((position.u - before.u).powi(2) + (position.v - before.v).powi(2)).sqrt();
            let speed = distance * 1000.0 / gap_ms as f64;
            let first_bin = (before.timestamp_ms / config.bin_ms) as usize;
            let last_bin = ((position.timestamp_ms - 1) / config.bin_ms) as usize;
            for (index, bin) in bins
                .iter_mut()
                .enumerate()
                .take(last_bin + 1)
                .skip(first_bin)
            {
                let midpoint = (index as i64)
                    .saturating_mul(config.bin_ms)
                    .saturating_add(config.bin_ms / 2)
                    .min(input.duration_ms - 1);
                if input
                    .coverage
                    .iter()
                    .any(|interval| interval.contains(midpoint))
                {
                    bin.motion += speed;
                    bin.pairs += 1;
                }
            }
        }
    }

    if let Some(audio) = &input.audio {
        for sample in audio {
            cancel.check()?;
            let index = (sample.timestamp_ms / config.bin_ms) as usize;
            bins[index].audio = bins[index].audio.max(sample.value);
        }
    }

    let usable_bins = bins.iter().filter(|bin| bin.pairs > 0).count();
    let usable_coverage = usable_bins as f64 / bin_count as f64;
    if usable_bins == 0 || usable_coverage < config.min_usable_coverage {
        return Err(invalid(format!(
            "player tracks have insufficient usable coverage: {:.1}% of the recording",
            usable_coverage * 100.0
        )));
    }

    let mut states = Vec::with_capacity(bin_count as usize);
    let mut in_rally = false;
    for bin in &bins {
        cancel.check()?;
        if bin.pairs == 0 {
            states.push(SpanKind::Unknown);
            in_rally = false;
            continue;
        }
        let active = if in_rally {
            bin.motion >= config.exit_motion_per_second
        } else {
            bin.motion >= config.enter_motion_per_second
                || (bin.motion >= config.exit_motion_per_second
                    && bin.audio >= config.audio_intensity_threshold
                    && input.audio.is_some())
        };
        in_rally = active;
        states.push(if active {
            SpanKind::Rally
        } else {
            SpanKind::Rest
        });
    }

    smooth_short_rest(&mut states, config.bin_ms, config.min_rest_ms);
    discard_short_rallies(
        &mut states,
        config.bin_ms,
        input.duration_ms,
        config.min_rally_ms,
    );

    let timeline = collect_spans(&states, config.bin_ms, input.duration_ms);
    let rallies = timeline
        .iter()
        .filter(|span| span.kind == SpanKind::Rally)
        .map(|span| {
            let first = (span.time.start_ms / config.bin_ms) as usize;
            let last = ((span.time.end_ms - 1) / config.bin_ms) as usize;
            let quality = bins[first..=last]
                .iter()
                .map(|bin| {
                    let activity = (bin.motion / (2.0 * config.enter_motion_per_second)).min(1.0);
                    let support = (bin.pairs as f64 / 2.0).min(1.0);
                    activity * support
                })
                .sum::<f64>()
                / (last - first + 1) as f64;
            RallyCandidate {
                time: span.time,
                quality: quality.clamp(0.0, 1.0),
                audio_available: input.audio.is_some(),
            }
        })
        .collect();

    Ok(SegmentationResult {
        rallies,
        timeline,
        usable_coverage,
        audio_available: input.audio.is_some(),
    })
}

fn validate_input(input: &SegmentationInput) -> Result<()> {
    if input.duration_ms <= 0 {
        return Err(invalid("recording duration must be positive"));
    }
    if input.calibration_id.trim().is_empty() {
        return Err(invalid("a court calibration identity is required"));
    }
    if input.coverage.is_empty() {
        return Err(invalid("player track coverage is missing"));
    }
    let mut last_end = 0;
    for interval in &input.coverage {
        if interval.start_ms < last_end
            || interval.start_ms < 0
            || interval.end_ms <= interval.start_ms
            || interval.end_ms > input.duration_ms
        {
            return Err(invalid(
                "track coverage intervals must be ordered, non-overlapping, and within the recording",
            ));
        }
        last_end = interval.end_ms;
    }
    if input.positions.is_empty() {
        return Err(invalid("player tracks are missing"));
    }
    let mut last_timestamp = -1;
    for position in &input.positions {
        if position.timestamp_ms < 0
            || position.timestamp_ms < last_timestamp
            || position.timestamp_ms >= input.duration_ms
            || !unit(position.u)
            || !unit(position.v)
        {
            return Err(invalid(
                "track positions must be ordered, on the recording timeline, and inside the normalized court",
            ));
        }
        last_timestamp = position.timestamp_ms;
    }
    if let Some(audio) = &input.audio {
        let mut last_timestamp = -1;
        for sample in audio {
            if sample.timestamp_ms < 0
                || sample.timestamp_ms < last_timestamp
                || sample.timestamp_ms >= input.duration_ms
                || !unit(sample.value)
            {
                return Err(invalid(
                    "audio intensities must be ordered, on the recording timeline, and normalized",
                ));
            }
            last_timestamp = sample.timestamp_ms;
        }
    }
    Ok(())
}

fn smooth_short_rest(states: &mut [SpanKind], bin_ms: i64, min_rest_ms: i64) {
    let mut index = 0;
    while index < states.len() {
        if states[index] != SpanKind::Rest {
            index += 1;
            continue;
        }
        let start = index;
        while index < states.len() && states[index] == SpanKind::Rest {
            index += 1;
        }
        if start > 0
            && index < states.len()
            && states[start - 1] == SpanKind::Rally
            && states[index] == SpanKind::Rally
            && ((index - start) as i64) * bin_ms < min_rest_ms
        {
            states[start..index].fill(SpanKind::Rally);
        }
    }
}

fn discard_short_rallies(
    states: &mut [SpanKind],
    bin_ms: i64,
    duration_ms: i64,
    min_rally_ms: i64,
) {
    let mut index = 0;
    while index < states.len() {
        if states[index] != SpanKind::Rally {
            index += 1;
            continue;
        }
        let start = index;
        while index < states.len() && states[index] == SpanKind::Rally {
            index += 1;
        }
        let start_ms = start as i64 * bin_ms;
        let end_ms = (index as i64).saturating_mul(bin_ms).min(duration_ms);
        if end_ms - start_ms < min_rally_ms {
            states[start..index].fill(SpanKind::Rest);
        }
    }
}

fn collect_spans(states: &[SpanKind], bin_ms: i64, duration_ms: i64) -> Vec<ClassifiedSpan> {
    let mut spans = Vec::new();
    let mut index = 0;
    while index < states.len() {
        let start = index;
        let kind = states[index];
        while index < states.len() && states[index] == kind {
            index += 1;
        }
        spans.push(ClassifiedSpan {
            time: TimeSpan {
                start_ms: start as i64 * bin_ms,
                end_ms: (index as i64 * bin_ms).min(duration_ms),
            },
            kind,
        });
    }
    spans
}

fn unit(value: f64) -> bool {
    value.is_finite() && (0.0..=1.0).contains(&value)
}

fn invalid(message: impl Into<String>) -> SportcutError {
    SportcutError::InvalidInput(format!("rally segmentation: {}", message.into()))
}
