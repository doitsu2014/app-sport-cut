//! Highlight ranking.
//!
//! Ranks the rallies the caller already holds by duration, optional motion
//! quality, and score context, so the application can surface the best
//! highlight candidates first. The engine never reads the application's
//! catalog: the caller supplies the rally list and the signals it already has.

#![forbid(unsafe_code)]

use sportcut_common::{Result, SportcutError};

/// The signals one rally contributes to its highlight score.
#[derive(Debug, Clone, PartialEq)]
pub struct HighlightRally {
    /// Stable identity in the caller's records.
    pub id: String,
    /// Start on the recording timeline, in milliseconds.
    pub start_ms: i64,
    /// End on the recording timeline, in milliseconds.
    pub end_ms: i64,
    /// Motion quality from analysis, `0.0..=1.0`, when the rally came from a
    /// suggestion; `None` for a hand-marked rally.
    pub motion: Option<f64>,
    /// Score context from `0.0..=1.0`: importance of the point, `0` when the
    /// rally is unscored.
    pub score_context: f64,
}

/// One rally's place in the suggested highlight order.
#[derive(Debug, Clone, PartialEq)]
pub struct HighlightRank {
    /// Stable identity in the caller's records.
    pub id: String,
    /// Highlight score from `0.0..=1.0`, higher is better.
    pub score: f64,
    /// `1`-based rank, best first.
    pub rank: u32,
}

/// Rank rallies into a suggested highlight order.
///
/// Deterministic: the same inputs always produce the same scores and ranks.
/// Ties break by earlier start time so a stable input order is not required.
pub fn rank(rallies: &[HighlightRally]) -> Result<Vec<HighlightRank>> {
    validate(rallies)?;

    let mut scored: Vec<HighlightRank> = rallies
        .iter()
        .map(|rally| HighlightRank {
            id: rally.id.clone(),
            score: score(rally),
            rank: 0,
        })
        .collect();

    // Order by score descending, then by earlier start for stability.
    let mut by_score: Vec<usize> = (0..scored.len()).collect();
    by_score.sort_by(|&a, &b| {
        scored[b]
            .score
            .total_cmp(&scored[a].score)
            .then_with(|| rallies[a].start_ms.cmp(&rallies[b].start_ms))
    });
    for (rank_index, original_index) in by_score.iter().enumerate() {
        scored[*original_index].rank = (rank_index + 1) as u32;
    }

    Ok(scored)
}

fn score(rally: &HighlightRally) -> f64 {
    let duration_seconds = ((rally.end_ms - rally.start_ms) as f64 / 1000.0).max(0.0);
    let duration = (duration_seconds / 30.0).clamp(0.0, 1.0);
    let motion = rally.motion.unwrap_or(0.5).clamp(0.0, 1.0);
    let context = rally.score_context.clamp(0.0, 1.0);
    // ponytail: fixed weights chosen by hand; re-tune once ranked footage exists.
    (0.40 * duration + 0.30 * motion + 0.30 * context).clamp(0.0, 1.0)
}

fn validate(rallies: &[HighlightRally]) -> Result<()> {
    for rally in rallies {
        if rally.id.trim().is_empty() {
            return Err(invalid("a rally id must not be empty"));
        }
        if rally.end_ms <= rally.start_ms {
            return Err(invalid(format!(
                "rally {} must end after it starts",
                rally.id
            )));
        }
        if let Some(motion) = rally.motion {
            if !unit(motion) {
                return Err(invalid(format!(
                    "rally {} motion is outside 0.0..=1.0",
                    rally.id
                )));
            }
        }
        if !unit(rally.score_context) {
            return Err(invalid(format!(
                "rally {} score context is outside 0.0..=1.0",
                rally.id
            )));
        }
    }
    Ok(())
}

fn unit(value: f64) -> bool {
    value.is_finite() && (0.0..=1.0).contains(&value)
}

fn invalid(message: impl Into<String>) -> SportcutError {
    SportcutError::InvalidInput(format!("highlight ranking: {}", message.into()))
}
