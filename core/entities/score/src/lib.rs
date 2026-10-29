//! Score suggestion.
//!
//! Derives who served each rally from the confirmed winners using badminton's
//! rally-point rule (the winner of a rally serves the next one), so the
//! application can propose the server as a tentative winner and show who serves
//! next. The product is explicitly not an automated referee: this crate
//! suggests, and the application confirms.

#![forbid(unsafe_code)]

use sportcut_common::{Result, SportcutError};

/// Which side of the court a result refers to.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Side {
    /// The left-hand side of the court.
    Left,
    /// The right-hand side of the court.
    Right,
}

/// One rally's known outcome, in recording order.
#[derive(Debug, Clone, PartialEq)]
pub struct RallyOutcome {
    /// Stable identity in the caller's records.
    pub id: String,
    /// Confirmed winner, or `None` while the rally is unscored.
    pub winner: Option<Side>,
}

/// Who served a rally.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServingSide {
    /// Stable identity in the caller's records.
    pub id: String,
    /// The side that served this rally, or `None` when it cannot be derived
    /// (the first rally, or the immediately previous rally is unscored).
    pub side: Option<Side>,
}

/// Derive who served each rally.
///
/// Badminton's rule is local: the winner of a rally serves the next one, so
/// each rally's server is the winner of the rally immediately before it. The
/// first rally has no previous winner and therefore no server.
pub fn serving_sides(rallies: &[RallyOutcome]) -> Result<Vec<ServingSide>> {
    let mut sides = Vec::with_capacity(rallies.len());
    let mut previous_winner: Option<Side> = None;
    for rally in rallies {
        if rally.id.trim().is_empty() {
            return Err(SportcutError::InvalidInput(
                "score suggestion: a rally id must not be empty".to_string(),
            ));
        }
        sides.push(ServingSide {
            id: rally.id.clone(),
            side: previous_winner,
        });
        previous_winner = rally.winner;
    }
    Ok(sides)
}
