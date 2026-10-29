//! Shared primitives and entities for the Sportcut engine.
//!
//! This is the innermost layer: it depends on no other workspace crate, and
//! every other crate may depend on it. `tools/check-layering.sh` enforces both
//! halves of that rule.
//!
//! What lives here is what more than one layer would otherwise have to reach
//! sideways for:
//!
//! * [`SportcutError`] / [`Result`] — the single error type every crate returns
//!   and every boundary translates into.
//! * [`CancelToken`], [`ProgressEvent`], and [`ProgressSink`] — the reporting
//!   primitives the media pipeline accepts, so it can report progress and react
//!   to cancellation without the media crate depending on the job crate.
//! * [`artifact`] — the manifest entities and the match-directory layout, so the
//!   media pipeline, the job model, and the storage adapter agree on what an
//!   artifact is without the use-case crates depending on the gateway that
//!   persists it.
//! * [`SampledFrame`] — the frame the media pipeline produces and the vision
//!   pipeline consumes.

pub mod artifact;
mod cancel;
mod error;
mod progress;
mod sampling;

pub use artifact::{
    now_rfc3339, ArtifactEntry, ArtifactKind, ArtifactManifest, ArtifactState, ManifestSummary,
    MatchLayout, OriginalMedia, ARTIFACT_DIRS, CHECKPOINT_FILE, MANIFEST_FILE,
};
pub use cancel::CancelToken;
pub use error::{Result, SportcutError};
pub use progress::{NoopProgress, ProgressEvent, ProgressSink};
pub use sampling::SampledFrame;
