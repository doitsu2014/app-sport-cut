//! Stable job identifiers.

use std::fmt;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

/// Identifier of a job.
///
/// Generated once and written into the checkpoint file, so a job interrupted by
/// an application restart is still identifiable.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct JobId(String);

impl JobId {
    /// Generate a new identifier.
    ///
    /// Combines the process id, the clock, and a process-local counter. No
    /// random number generator is needed: the identifier only has to be unique
    /// among the jobs a device can have in flight, and it is written to the
    /// checkpoint file rather than kept secret.
    pub fn generate() -> Self {
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let sequence = COUNTER.fetch_add(1, Ordering::Relaxed);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_nanos())
            .unwrap_or_default();
        Self(format!(
            "job-{:x}-{nanos:x}-{sequence:x}",
            std::process::id()
        ))
    }

    /// Build an identifier from a stored string.
    pub fn from_string(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    /// The identifier as a string.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for JobId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}
