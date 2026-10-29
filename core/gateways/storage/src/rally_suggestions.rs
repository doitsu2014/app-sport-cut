//! Persistence of the derived rally suggestion set.
//!
//! The suggestion model — its versioning, its input identity, and the rule that
//! a generation matches the inputs it claims — is an entity in
//! `sportcut_rally::suggestions`. This module only puts it on disk and
//! republishes it in the manifest.

use std::path::Path;

use sportcut_common::artifact::{ArtifactKind, ArtifactState};
use sportcut_common::{Result, SportcutError};
use sportcut_rally::{RallySuggestions, SuggestionInputs};

use crate::manifest::{load_manifest, save_manifest};
use crate::match_dir::MatchDirectory;

pub use sportcut_rally::{RALLY_SEGMENTER_VERSION, RALLY_SUGGESTIONS_SCHEMA_VERSION};

/// Location of the suggestion set in the existing match-directory layout.
pub const RALLY_SUGGESTIONS_RELATIVE_PATH: &str = "tracks/rally_suggestions.json";

/// Save a completed suggestion set and then publish it in the manifest.
///
/// The job must check cancellation before calling this function. An interrupted
/// write cannot expose a partial JSON file as a final result.
pub fn save_rally_suggestions(
    match_dir: &MatchDirectory,
    suggestions: &RallySuggestions,
) -> Result<()> {
    suggestions.validate()?;
    let manifest_path = match_dir.manifest_path();
    let mut manifest = load_manifest(&manifest_path)?;
    let path = match_dir.resolve(RALLY_SUGGESTIONS_RELATIVE_PATH);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| SportcutError::io(parent, error))?;
    }
    let bytes = serde_json::to_vec_pretty(suggestions).map_err(|error| {
        SportcutError::Artifact(format!("could not serialize rally suggestions: {error}"))
    })?;
    let temporary = path.with_extension("json.writing");
    std::fs::write(&temporary, bytes).map_err(|error| SportcutError::io(&temporary, error))?;
    std::fs::rename(&temporary, &path).map_err(|error| SportcutError::io(&path, error))?;

    manifest.record_artifact(
        ArtifactKind::RallySuggestions,
        RALLY_SUGGESTIONS_RELATIVE_PATH,
        ArtifactState::Final,
        std::fs::metadata(&path).ok().map(|metadata| metadata.len()),
    );
    save_manifest(&mut manifest, &manifest_path)
}

/// Read only a final result that belongs to the current input generation.
///
/// `None` means missing, partial, or stale; callers can offer regeneration.
pub fn load_rally_suggestions(
    match_dir: &MatchDirectory,
    expected_inputs: &SuggestionInputs,
) -> Result<Option<RallySuggestions>> {
    expected_inputs.validate()?;
    let manifest_path = match_dir.manifest_path();
    if !manifest_path.is_file() {
        return Ok(None);
    }
    let manifest = load_manifest(&manifest_path)?;
    let Some(entry) = manifest.entry(ArtifactKind::RallySuggestions) else {
        return Ok(None);
    };
    if entry.state != ArtifactState::Final || entry.relative_path != RALLY_SUGGESTIONS_RELATIVE_PATH
    {
        return Ok(None);
    }
    let path = match_dir.resolve(RALLY_SUGGESTIONS_RELATIVE_PATH);
    if !path.is_file() {
        return Ok(None);
    }
    let suggestions = read_file(&path)?;
    suggestions.validate()?;
    if suggestions.inputs != *expected_inputs {
        return Ok(None);
    }
    Ok(Some(suggestions))
}

fn read_file(path: &Path) -> Result<RallySuggestions> {
    let bytes = std::fs::read(path).map_err(|error| SportcutError::io(path, error))?;
    serde_json::from_slice(&bytes).map_err(|error| {
        SportcutError::Artifact(format!(
            "{} is not a readable rally suggestion set: {error}",
            path.display()
        ))
    })
}
