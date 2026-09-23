//! The on-disk layout of one match's artifact directory.

use std::path::{Path, PathBuf};

use sportcut_common::{Result, SportcutError};

use crate::manifest::ArtifactManifest;

/// File name of the artifact manifest inside a match directory.
pub const MANIFEST_FILE: &str = "manifest.json";

/// File name of the job checkpoint file inside a match directory.
pub const CHECKPOINT_FILE: &str = "checkpoints.json";

/// Sub-directories the engine writes derived artifacts into.
pub const ARTIFACT_DIRS: [&str; 6] = [
    "proxy",
    "audio",
    "frames",
    "calibration",
    "tracks",
    "export",
];

/// A match's artifact directory.
#[derive(Debug, Clone)]
pub struct MatchDirectory {
    root: PathBuf,
}

impl MatchDirectory {
    /// Wrap an existing or not-yet-created match directory.
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Create the directory and its artifact sub-directories.
    pub fn create(&self) -> Result<()> {
        std::fs::create_dir_all(&self.root).map_err(|e| SportcutError::io(&self.root, e))?;
        for dir in ARTIFACT_DIRS {
            let path = self.root.join(dir);
            std::fs::create_dir_all(&path).map_err(|e| SportcutError::io(&path, e))?;
        }
        Ok(())
    }

    /// Root path of this match directory.
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Path of the artifact manifest.
    pub fn manifest_path(&self) -> PathBuf {
        self.root.join(MANIFEST_FILE)
    }

    /// Path of the job checkpoint file.
    pub fn checkpoint_path(&self) -> PathBuf {
        self.root.join(CHECKPOINT_FILE)
    }

    /// Path of one of the artifact sub-directories.
    pub fn artifact_dir(&self, name: &str) -> PathBuf {
        self.root.join(name)
    }

    /// Turn an absolute path inside this directory into a relative one.
    pub fn relativize(&self, path: &Path) -> Result<String> {
        path.strip_prefix(&self.root)
            .map(|relative| relative.to_string_lossy().replace('\\', "/"))
            .map_err(|_| {
                SportcutError::Artifact(format!(
                    "{} is outside the match directory {}",
                    path.display(),
                    self.root.display()
                ))
            })
    }

    /// Resolve a manifest-relative artifact path against this directory.
    pub fn resolve(&self, relative: &str) -> PathBuf {
        self.root.join(relative)
    }

    /// Load the manifest, or create an empty one referencing `original`.
    pub fn load_or_init_manifest(&self, original: &Path) -> Result<ArtifactManifest> {
        let path = self.manifest_path();
        if path.is_file() {
            ArtifactManifest::load(&path)
        } else {
            Ok(ArtifactManifest::new(
                self.root
                    .file_name()
                    .map(|name| name.to_string_lossy().to_string())
                    .unwrap_or_else(|| "match".to_string()),
                original,
            ))
        }
    }
}
