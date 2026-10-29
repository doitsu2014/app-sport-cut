//! Frames sampled from a recording.
//!
//! One sampled frame is the unit the media pipeline produces and the vision
//! pipeline consumes. It lives in the entity layer so vision can be handed
//! frames without depending on the media crate that sampled them.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

/// One sampled frame, mapped back to the original recording timeline.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SampledFrame {
    /// Zero-based index in the sampled stream.
    pub index: u32,
    /// Timestamp on the original recording timeline, in milliseconds.
    pub timestamp_ms: i64,
    /// Path of the written frame file.
    pub path: PathBuf,
}
