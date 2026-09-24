//! Per-match artifact storage.
//!
//! The engine owns artifact files; the Flutter application owns the SQLite
//! catalog. Everything the engine produces for one match lives under a single
//! directory and is described by `manifest.json`:

mod calibration;
mod manifest;
mod match_dir;

pub use calibration::{
    load_calibration, save_calibration, CalibrationSave, CALIBRATION_RELATIVE_PATH,
};
pub use manifest::{
    now_rfc3339, ArtifactEntry, ArtifactKind, ArtifactManifest, ArtifactState, ManifestSummary,
    OriginalMedia,
};
pub use match_dir::{MatchDirectory, CHECKPOINT_FILE, MANIFEST_FILE};
