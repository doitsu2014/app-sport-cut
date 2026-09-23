//! Shared primitives for the Sportcut engine.
//!
//! Two things live here because otherwise they would create a dependency cycle
//! between the media pipeline, the artifact storage, and the job model:
//!
//! * [`SportcutError`] / [`Result`] — the single error type every crate returns
//!   and every boundary translates into.
//! * [`CancelToken`], [`ProgressEvent`], and [`ProgressSink`] — the reporting
//!   primitives the media pipeline accepts, so it can report progress and react
//!   to cancellation without the media crate depending on the job crate.

mod cancel;
mod error;
mod progress;

pub use cancel::CancelToken;
pub use error::{Result, SportcutError};
pub use progress::{NoopProgress, ProgressEvent, ProgressSink};
