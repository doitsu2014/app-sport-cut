//! Token generation, endpoint validation, and file-mode helpers.
//!
//! Protocol §1.1 and §2.4: the socket directory is `0700`, the socket and
//! token file are `0600`, the endpoint must fit in `sockaddr_un.sun_path`
//! (103 UTF-8 bytes plus the NUL terminator), and the token is compared in
//! constant time. The token is never logged.

use std::ffi::OsString;
use std::fmt::Write as _;
use std::fs::{self, OpenOptions};
use std::io::Write as _;
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use rand::RngCore;

/// Largest endpoint path, in UTF-8 bytes, excluding the NUL terminator.
pub const ENDPOINT_MAX_BYTES: usize = 103;

/// Mode for the run directory and other service-private directories.
pub const PRIVATE_DIRECTORY_MODE: u32 = 0o700;

/// Mode for the socket and token file.
pub const PRIVATE_FILE_MODE: u32 = 0o600;

/// A fresh per-launch token: 32 lowercase hex characters from 16 random bytes.
pub fn generate_token() -> String {
    let mut bytes = [0_u8; 16];
    rand::thread_rng().fill_bytes(&mut bytes);
    let mut token = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        // Writing to a `String` cannot fail.
        let _ = write!(token, "{byte:02x}");
    }
    token
}

/// Refuse an endpoint that cannot fit in `sockaddr_un.sun_path`.
///
/// This runs before any directory is created or socket is bound, and it never
/// truncates or falls back to another path.
pub fn ensure_endpoint_fits(endpoint: &Path) -> Result<()> {
    let bytes = endpoint.as_os_str().as_encoded_bytes().len();
    if bytes > ENDPOINT_MAX_BYTES {
        bail!(
            "endpoint_too_long: the Unix socket path {:?} is {bytes} UTF-8 bytes, which exceeds \
             the {ENDPOINT_MAX_BYTES}-byte limit of sockaddr_un.sun_path; pass a shorter \
             --endpoint path",
            endpoint
        );
    }
    Ok(())
}

/// Write `token` to `path` with mode `0600`, atomically via a temporary file.
///
/// The parent directory is created `0700`. The temporary file is flushed to
/// disk before the rename so a crash cannot expose a short token.
pub fn write_token_file(path: &Path, token: &str) -> Result<()> {
    let parent = path
        .parent()
        .with_context(|| format!("token file {} has no parent directory", path.display()))?;
    ensure_private_directory(parent)?;

    let mut temporary: OsString = path.as_os_str().to_owned();
    temporary.push(format!(".tmp.{}", std::process::id()));
    let temporary = PathBuf::from(temporary);

    let result = write_then_rename(&temporary, path, token);
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

fn write_then_rename(temporary: &Path, destination: &Path, token: &str) -> Result<()> {
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(PRIVATE_FILE_MODE)
        .open(temporary)
        .with_context(|| format!("failed to create the token file {}", temporary.display()))?;
    file.write_all(token.as_bytes())
        .with_context(|| format!("failed to write the token file {}", temporary.display()))?;
    file.sync_all()
        .with_context(|| format!("failed to flush the token file {}", temporary.display()))?;
    drop(file);

    set_mode(temporary, PRIVATE_FILE_MODE)?;
    fs::rename(temporary, destination).with_context(|| {
        format!(
            "failed to move the token file into place at {}",
            destination.display()
        )
    })?;
    Ok(())
}

/// Create `directory` if needed and force its mode to `0700`.
pub fn ensure_private_directory(directory: &Path) -> Result<()> {
    fs::create_dir_all(directory)
        .with_context(|| format!("failed to create the directory {}", directory.display()))?;
    set_mode(directory, PRIVATE_DIRECTORY_MODE)
}

/// Force a path's permission bits.
pub fn set_mode(path: &Path, mode: u32) -> Result<()> {
    fs::set_permissions(path, fs::Permissions::from_mode(mode))
        .with_context(|| format!("failed to set mode {mode:o} on {}", path.display()))
}

/// Compare two tokens without leaking where they differ.
///
/// Token length is fixed by [`generate_token`], so an early length comparison
/// does not reveal secret content.
pub fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    let mut difference = 0_u8;
    for (left, right) in left.iter().zip(right) {
        difference |= left ^ right;
    }
    difference == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokens_are_32_hex_characters_and_unique() {
        let first = generate_token();
        let second = generate_token();
        assert_eq!(first.len(), 32);
        assert!(first.chars().all(|c| c.is_ascii_hexdigit()));
        assert_ne!(first, second);
    }

    #[test]
    fn constant_time_equality_matches_normal_equality() {
        assert!(constant_time_eq(b"token", b"token"));
        assert!(!constant_time_eq(b"token", b"toker"));
        assert!(!constant_time_eq(b"token", b"tok"));
        assert!(constant_time_eq(b"", b""));
    }

    #[test]
    fn endpoints_at_the_limit_are_accepted_and_longer_ones_refused() {
        let at_limit = PathBuf::from("a".repeat(ENDPOINT_MAX_BYTES));
        assert!(ensure_endpoint_fits(&at_limit).is_ok());

        let too_long = PathBuf::from("a".repeat(ENDPOINT_MAX_BYTES + 1));
        let error = ensure_endpoint_fits(&too_long).expect_err("too long");
        let message = format!("{error:#}");
        assert!(message.contains("endpoint_too_long"), "{message}");
        assert!(message.contains("103"), "{message}");
        assert!(
            message.contains(&(ENDPOINT_MAX_BYTES + 1).to_string()),
            "{message}"
        );
    }

    #[test]
    fn the_token_file_is_created_private_and_replaced() {
        let directory = tempfile::tempdir().expect("temp dir");
        let path = directory.path().join("run").join("token");

        write_token_file(&path, "first").expect("write token");
        assert_eq!(fs::read_to_string(&path).expect("read token"), "first");
        let mode = fs::metadata(&path).expect("metadata").permissions().mode() & 0o777;
        assert_eq!(mode, PRIVATE_FILE_MODE);

        write_token_file(&path, "second").expect("replace token");
        assert_eq!(fs::read_to_string(&path).expect("read token"), "second");

        let run_mode = fs::metadata(path.parent().expect("parent"))
            .expect("run metadata")
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(run_mode, PRIVATE_DIRECTORY_MODE);
    }
}
