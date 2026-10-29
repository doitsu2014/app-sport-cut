//! The service state-root layout.
//!
//! Layout from background-service §6.1. Phase 0-1 creates the directories the
//! transport and lifecycle need and the paths the handshake reports; catalog,
//! recording, and artifact contents arrive in later phases.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

use crate::security::ensure_private_directory;

/// Absolute paths derived from one state root.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Layout {
    /// The root itself.
    pub root: PathBuf,
    /// `run/` for the lock and token.
    pub run: PathBuf,
    /// `recordings/` for service-owned recordings.
    pub recordings: PathBuf,
    /// `matches/` for artifact directories.
    pub matches: PathBuf,
    /// `render-inputs/` for export inputs.
    pub render_inputs: PathBuf,
    /// `inbox/` for the sandbox file handoff.
    pub inbox: PathBuf,
    /// `logs/` for the local service log.
    pub logs: PathBuf,
    /// `backups/` for migration copies.
    pub backups: PathBuf,
}

impl Layout {
    /// Resolve and create the layout under `root`.
    ///
    /// The root is made absolute so every path the handshake reports is
    /// absolute, as protocol §7 requires. Each directory is created `0700`.
    pub fn prepare(root: &Path) -> Result<Self> {
        let root = absolute(root)?;
        let layout = Self {
            run: root.join("run"),
            recordings: root.join("recordings"),
            matches: root.join("matches"),
            render_inputs: root.join("render-inputs"),
            inbox: root.join("inbox"),
            logs: root.join("logs"),
            backups: root.join("backups"),
            root,
        };

        for directory in [
            &layout.root,
            &layout.run,
            &layout.recordings,
            &layout.matches,
            &layout.render_inputs,
            &layout.inbox,
            &layout.logs,
            &layout.backups,
        ] {
            ensure_private_directory(directory)?;
        }

        Ok(layout)
    }

    /// `<state-root>/run/token`.
    pub fn default_token_file(&self) -> PathBuf {
        self.run.join("token")
    }

    /// `<state-root>/run/service.lock`.
    pub fn lock_file(&self) -> PathBuf {
        self.run.join("service.lock")
    }
}

fn absolute(path: &Path) -> Result<PathBuf> {
    std::path::absolute(path)
        .with_context(|| format!("failed to resolve the absolute path of {}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn prepare_creates_every_directory_private() {
        let directory = tempfile::tempdir().expect("temp dir");
        let layout = Layout::prepare(&directory.path().join("state")).expect("prepare");

        for path in [
            &layout.root,
            &layout.run,
            &layout.recordings,
            &layout.matches,
            &layout.render_inputs,
            &layout.inbox,
            &layout.logs,
            &layout.backups,
        ] {
            assert!(path.is_dir(), "{} is a directory", path.display());
            let mode = std::fs::metadata(path)
                .expect("metadata")
                .permissions()
                .mode()
                & 0o777;
            assert_eq!(mode, 0o700, "{} is private", path.display());
        }

        assert!(layout.root.is_absolute());
        assert_eq!(layout.default_token_file(), layout.run.join("token"));
        assert_eq!(layout.lock_file(), layout.run.join("service.lock"));
    }
}
