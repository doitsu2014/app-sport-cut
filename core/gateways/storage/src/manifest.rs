//! Reading and writing the per-match manifest.
//!
//! The manifest *model* is an entity and lives in `sportcut-common`; this module
//! is the gateway that puts it on disk. Keeping the two apart is what lets the
//! media pipeline record artifacts without depending on the storage crate that
//! persists them.

use std::path::Path;

use sportcut_common::artifact::{ArtifactKind, ArtifactManifest, ManifestSummary};
use sportcut_common::{Result, SportcutError};

/// Read a manifest from disk.
///
/// A file written by a newer engine is rejected explicitly rather than being
/// silently half-understood: serde would fail on an unknown artifact kind, and
/// "unreadable" is a worse answer than "this build is too old".
pub fn load_manifest(path: &Path) -> Result<ArtifactManifest> {
    let bytes = std::fs::read(path).map_err(|e| SportcutError::io(path, e))?;
    let manifest: ArtifactManifest = serde_json::from_slice(&bytes).map_err(|e| {
        SportcutError::Artifact(format!(
            "{} is not a readable manifest: {e}",
            path.display()
        ))
    })?;
    if manifest.schema_version > ArtifactManifest::SCHEMA_VERSION {
        return Err(SportcutError::Artifact(format!(
            "{} was written by a newer engine (schema {} > {})",
            path.display(),
            manifest.schema_version,
            ArtifactManifest::SCHEMA_VERSION
        )));
    }
    Ok(manifest)
}

/// Write the manifest to disk atomically, updating `updated_at`.
pub fn save_manifest(manifest: &mut ArtifactManifest, path: &Path) -> Result<()> {
    manifest.schema_version = ArtifactManifest::SCHEMA_VERSION;
    manifest.updated_at = sportcut_common::artifact::now_rfc3339();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| SportcutError::io(parent, e))?;
    }
    let json = serde_json::to_vec_pretty(manifest)
        .map_err(|e| SportcutError::Artifact(format!("could not serialize manifest: {e}")))?;
    let temporary = path.with_extension("json.writing");
    std::fs::write(&temporary, json).map_err(|e| SportcutError::io(&temporary, e))?;
    std::fs::rename(&temporary, path).map_err(|e| SportcutError::io(path, e))?;
    Ok(())
}

/// Summarize completeness, checking the filesystem for each artifact.
pub fn summarize_manifest(manifest: &ArtifactManifest, root: &Path) -> ManifestSummary {
    use sportcut_common::artifact::ArtifactState;

    let mut summary = ManifestSummary {
        match_id: manifest.match_id.clone(),
        complete: Vec::new(),
        missing: Vec::new(),
        non_final: Vec::new(),
        original_present: Path::new(&manifest.original.path).is_file(),
    };

    for entry in &manifest.artifacts {
        let path = root.join(&entry.relative_path);
        if !path.exists() {
            summary.missing.push(entry.kind);
        } else {
            match entry.state {
                ArtifactState::Final | ArtifactState::Missing => {
                    summary.complete.push(entry.kind);
                }
                ArtifactState::NonFinal => summary.non_final.push(entry.kind),
            }
        }
    }

    summary
}

/// Artifact kinds the manifest says exist but whose files are gone.
///
/// This is what makes derived artifacts regenerable: the application can ask for
/// exactly these to be rebuilt without re-importing the match.
pub fn missing_artifacts(manifest: &ArtifactManifest, root: &Path) -> Vec<ArtifactKind> {
    manifest
        .artifacts
        .iter()
        .filter(|entry| !root.join(&entry.relative_path).exists())
        .map(|entry| entry.kind)
        .collect()
}
