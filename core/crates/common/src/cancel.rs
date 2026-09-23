//! Cooperative cancellation.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// A cheap, cloneable cancellation signal.
///
/// Long-running stages check [`CancelToken::is_cancelled`] between work units
/// and return [`crate::SportcutError::Cancelled`] when it flips. Clones share
/// one flag, so a job can hand a token to the media pipeline and still signal
/// it from another thread.
#[derive(Debug, Clone, Default)]
pub struct CancelToken {
    cancelled: Arc<AtomicBool>,
}

impl CancelToken {
    /// A fresh, un-cancelled token.
    pub fn new() -> Self {
        Self::default()
    }

    /// Signal cancellation to every holder of this token.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
    }

    /// Whether cancellation has been signalled.
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::SeqCst)
    }

    /// Return `Err(Cancelled)` when cancellation has been signalled.
    pub fn check(&self) -> crate::Result<()> {
        if self.is_cancelled() {
            Err(crate::SportcutError::Cancelled)
        } else {
            Ok(())
        }
    }
}
