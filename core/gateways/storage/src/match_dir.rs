//! The on-disk layout of one match's artifact directory.
//!
//! The path arithmetic is an entity ([`MatchLayout`], in `sportcut-common`);
//! this adapter owns the filesystem half — creating the directories, and
//! reading and writing the files inside them.

use std::path::{Path, PathBuf};

use sportcut_common::artifact::{ArtifactKind, ArtifactManifest, ManifestSummary, MatchLayout};
use sportcut_common::{Result, SportcutError};
use sportcut_media::ArtifactStore;

use crate::manifest::{load_manifest, missing_artifacts, save_manifest, summarize_manifest};

pub use sportcut_common::artifact::ARTIFACT_DIRS;

/// A match's artifact directory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchDirectory {
    layout: MatchLayout,
}

impl MatchDirectory {
    /// Wrap an existing or not-yet-created match directory.
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self {
            layout: MatchLayout::new(root),
        }
    }

    /// The pure path arithmetic behind this directory.
    pub fn layout(&self) -> &MatchLayout {
        &self.layout
    }

    /// Create the directory and its artifact sub-directories.
    pub fn create(&self) -> Result<()> {
        let root = self.layout.root();
        std::fs::create_dir_all(root).map_err(|e| SportcutError::io(root, e))?;
        for dir in ARTIFACT_DIRS {
            let path = root.join(dir);
            std::fs::create_dir_all(&path).map_err(|e| SportcutError::io(&path, e))?;
        }
        Ok(())
    }

    /// Root path of this match directory.
    pub fn root(&self) -> &Path {
        self.layout.root()
    }

    /// Match identifier, taken from the directory name.
    pub fn match_id(&self) -> String {
        self.layout.match_id()
    }

    /// Path of the artifact manifest.
    pub fn manifest_path(&self) -> PathBuf {
        self.layout.manifest_path()
    }

    /// Path of the job checkpoint file.
    pub fn checkpoint_path(&self) -> PathBuf {
        self.layout.checkpoint_path()
    }

    /// Path of one of the artifact sub-directories.
    pub fn artifact_dir(&self, name: &str) -> PathBuf {
        self.layout.artifact_dir(name)
    }

    /// Turn an absolute path inside this directory into a relative one.
    pub fn relativize(&self, path: &Path) -> Result<String> {
        self.layout.relativize(path)
    }

    /// Resolve a manifest-relative artifact path against this directory.
    pub fn resolve(&self, relative: &str) -> PathBuf {
        self.layout.resolve(relative)
    }

    /// Load the manifest, or create an empty one referencing `original`.
    pub fn load_or_init_manifest(&self, original: &Path) -> Result<ArtifactManifest> {
        let path = self.manifest_path();
        if path.is_file() {
            return load_manifest(&path);
        }
        // Initializing is the moment the recording is first inspected, so the
        // size recorded here is the one the pipeline reports until it re-probes.
        let mut manifest = ArtifactManifest::new(self.layout.match_id(), original);
        manifest.original.size_bytes = std::fs::metadata(original).ok().map(|meta| meta.len());
        Ok(manifest)
    }

    /// Load the manifest, failing when the match has none.
    pub fn load_manifest(&self) -> Result<ArtifactManifest> {
        let path = self.manifest_path();
        if !path.is_file() {
            return Err(SportcutError::Artifact(format!(
                "{} has no manifest",
                self.root().display()
            )));
        }
        load_manifest(&path)
    }

    /// Write the manifest, updating `updated_at`.
    pub fn save_manifest(&self, manifest: &mut ArtifactManifest) -> Result<()> {
        save_manifest(manifest, &self.manifest_path())
    }

    /// Summarize completeness, checking the filesystem for each artifact.
    pub fn summarize(&self, manifest: &ArtifactManifest) -> ManifestSummary {
        summarize_manifest(manifest, self.root())
    }

    /// Artifact kinds the manifest says exist but whose files are gone.
    pub fn missing_artifacts(&self, manifest: &ArtifactManifest) -> Vec<ArtifactKind> {
        missing_artifacts(manifest, self.root())
    }

    /// Mark every artifact in this match as non-final.
    ///
    /// Cancellation leaves partial output on disk for diagnosis, but nothing in
    /// it may be presented as a result.
    pub fn mark_artifacts_non_final(&self) -> Result<()> {
        let path = self.manifest_path();
        if !path.is_file() {
            return Ok(());
        }
        let mut manifest = load_manifest(&path)?;
        manifest.mark_all_non_final();
        save_manifest(&mut manifest, &path)
    }
}

impl From<&MatchDirectory> for MatchLayout {
    fn from(directory: &MatchDirectory) -> Self {
        directory.layout.clone()
    }
}

impl From<MatchLayout> for MatchDirectory {
    fn from(layout: MatchLayout) -> Self {
        Self { layout }
    }
}

impl ArtifactStore for MatchDirectory {
    fn root(&self) -> &Path {
        MatchDirectory::root(self)
    }

    fn ensure_created(&self) -> Result<()> {
        self.create()
    }

    fn resolve(&self, relative: &str) -> PathBuf {
        MatchDirectory::resolve(self, relative)
    }

    fn load_or_init_manifest(&self, original: &Path) -> Result<ArtifactManifest> {
        MatchDirectory::load_or_init_manifest(self, original)
    }

    fn load_manifest(&self) -> Result<ArtifactManifest> {
        MatchDirectory::load_manifest(self)
    }

    fn save_manifest(&self, manifest: &mut ArtifactManifest) -> Result<()> {
        MatchDirectory::save_manifest(self, manifest)
    }

    fn missing_artifacts(&self, manifest: &ArtifactManifest) -> Vec<ArtifactKind> {
        MatchDirectory::missing_artifacts(self, manifest)
    }
}
