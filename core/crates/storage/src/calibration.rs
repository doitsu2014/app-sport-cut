//! Court calibration inside a match directory.
//!
//! The application's catalog is the source of truth for a match's calibration:
//! it is the user's own input, it has to survive deleting the derived artifacts,
//! and the application owns the catalog. What lives here is the engine's
//! projection of that value into the match directory, so a headless run — the
//! CLI harness, an engine test, any later analysis stage — can work from the
//! directory alone.
//!
//! Nothing in the engine derives a calibration. A match that has none reports
//! none, and no court, net, or side is invented for it.

use std::path::Path;

use sportcut_common::{Result, SportcutError};
use sportcut_court::CourtCalibration;

use crate::manifest::{ArtifactKind, ArtifactManifest, ArtifactState};
use crate::match_dir::MatchDirectory;

/// Path of the calibration inside a match directory.
pub const CALIBRATION_RELATIVE_PATH: &str = "calibration/calibration.json";

/// Suffix of the file the calibration is written through before being moved
/// into place, so a failed write cannot destroy a calibration already stored.
const WRITE_SUFFIX: &str = ".writing";

/// Artifact kinds that stop describing a match when its court changes.
///
/// Tracks are positions in court coordinates, and rally suggestions are based
/// on those tracks. They are dropped from the manifest rather than deleted from
/// disk, so a cancelled rebuild still leaves the bytes behind for diagnosis.
const DERIVED_FROM_CALIBRATION: [ArtifactKind; 2] =
    [ArtifactKind::Tracks, ArtifactKind::RallySuggestions];

/// What saving a calibration did.
#[derive(Debug, Clone, PartialEq)]
pub struct CalibrationSave {
    /// Whether the stored calibration differs from the one it replaced.
    pub changed: bool,
    /// Artifact kinds dropped because they were derived from the previous
    /// calibration rather than the new one.
    pub invalidated: Vec<ArtifactKind>,
}

/// Read the calibration stored in a match directory.
///
/// `None` when the match has never been calibrated, which is a normal state
/// rather than an error.
pub fn load_calibration(match_dir: &MatchDirectory) -> Result<Option<CourtCalibration>> {
    let path = match_dir.resolve(CALIBRATION_RELATIVE_PATH);
    if !path.is_file() {
        return Ok(None);
    }

    let bytes = std::fs::read(&path).map_err(|error| SportcutError::io(&path, error))?;
    let calibration: CourtCalibration = serde_json::from_slice(&bytes).map_err(|error| {
        SportcutError::Artifact(format!(
            "{} is not a readable court calibration: {error}",
            path.display()
        ))
    })?;
    calibration.validate()?;
    Ok(Some(calibration))
}

/// Write a calibration into a match directory and record it in the manifest.
///
/// A calibration that differs from the one it replaces invalidates the artifacts
/// derived from the previous court; writing the same calibration again changes
/// nothing, so opening the screen and confirming does not discard analysis.
pub fn save_calibration(
    match_dir: &MatchDirectory,
    calibration: &CourtCalibration,
) -> Result<CalibrationSave> {
    calibration.validate()?;

    let manifest_path = match_dir.manifest_path();
    if !manifest_path.is_file() {
        return Err(SportcutError::Artifact(format!(
            "{} has no manifest; import the recording before calibrating it",
            match_dir.root().display()
        )));
    }

    // The stored file is a projection of the application's catalog, so an
    // unreadable one is not a reason to refuse a new calibration: it is replaced
    // rather than allowed to block the user out of their own recording. An IO
    // failure that matters reappears when the new file is written.
    let previous = load_calibration(match_dir).ok().flatten();
    let changed = previous.as_ref() != Some(calibration);

    let path = match_dir.resolve(CALIBRATION_RELATIVE_PATH);
    write_calibration(&path, calibration)?;

    let mut manifest = ArtifactManifest::load(&manifest_path)?;
    let invalidated = if changed {
        invalidate_derived(&mut manifest)
    } else {
        Vec::new()
    };

    manifest.record_artifact(
        ArtifactKind::Calibration,
        CALIBRATION_RELATIVE_PATH,
        ArtifactState::Final,
        std::fs::metadata(&path).ok().map(|metadata| metadata.len()),
    );
    manifest.save(&manifest_path)?;

    Ok(CalibrationSave {
        changed,
        invalidated,
    })
}

/// Write the calibration file through a temporary name and move it into place.
fn write_calibration(path: &Path, calibration: &CourtCalibration) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| SportcutError::io(parent, error))?;
    }

    let json = serde_json::to_vec_pretty(calibration).map_err(|error| {
        SportcutError::Artifact(format!(
            "could not serialize the court calibration: {error}"
        ))
    })?;

    let name = path
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_else(|| "calibration.json".to_string());
    let temporary = path.with_file_name(format!("{name}{WRITE_SUFFIX}"));
    std::fs::write(&temporary, json).map_err(|error| SportcutError::io(&temporary, error))?;
    std::fs::rename(&temporary, path).map_err(|error| SportcutError::io(path, error))?;
    Ok(())
}

/// Drop the artifact kinds a new court invalidates, answering which were there.
fn invalidate_derived(manifest: &mut ArtifactManifest) -> Vec<ArtifactKind> {
    let present: Vec<ArtifactKind> = DERIVED_FROM_CALIBRATION
        .iter()
        .copied()
        .filter(|kind| manifest.entry(*kind).is_some())
        .collect();
    if !present.is_empty() {
        manifest.forget(&DERIVED_FROM_CALIBRATION);
    }
    present
}
