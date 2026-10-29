//! Per-match artifact storage.
//!
//! This is the gateway layer: it implements the ports the use-case crates
//! declare — [`sportcut_media::ArtifactStore`] and [`sportcut_jobs::CheckpointStore`]
//! — and owns everything that touches the filesystem. The entity model it
//! stores (the artifact manifest, the match layout) lives in `sportcut-common`.
//!
//! The engine owns artifact files; the Flutter application owns the SQLite
//! catalog. Everything the engine produces for one match lives under a single
//! directory and is described by `manifest.json`.

mod calibration;
mod checkpoint;
mod manifest;
mod match_dir;
mod rally_suggestions;

pub use calibration::{
    load_calibration, save_calibration, CalibrationSave, CALIBRATION_RELATIVE_PATH,
};
pub use checkpoint::CheckpointStore;
pub use manifest::{load_manifest, missing_artifacts, save_manifest, summarize_manifest};
pub use match_dir::MatchDirectory;
pub use rally_suggestions::{
    load_rally_suggestions, save_rally_suggestions, RALLY_SEGMENTER_VERSION,
    RALLY_SUGGESTIONS_RELATIVE_PATH, RALLY_SUGGESTIONS_SCHEMA_VERSION,
};

// Re-exported so callers that already depend on this crate do not have to reach
// into `sportcut-common` for the model of what it stores.
pub use sportcut_common::artifact::now_rfc3339;
pub use sportcut_common::artifact::{
    ArtifactEntry, ArtifactKind, ArtifactManifest, ArtifactState, ManifestSummary, OriginalMedia,
    ARTIFACT_DIRS, CHECKPOINT_FILE, MANIFEST_FILE,
};
