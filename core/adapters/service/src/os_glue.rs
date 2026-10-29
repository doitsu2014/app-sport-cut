//! Isolated operating-system calls.
//!
//! Every call this service needs has a safe `nix` wrapper on the supported
//! platforms, so this module contains **no `unsafe` code** and needs no
//! `#[allow(unsafe_code)]`. The workspace denies `unsafe_code`; if a future
//! call has no safe binding it must be isolated here with a documented
//! `#[allow(unsafe_code)]` on the narrowest possible item and a comment naming
//! the missing wrapper and why the risk is bounded.
//!
//! Calls used:
//!
//! - `nix::unistd::getpeereid` for the peer UID on macOS/BSD, which requires
//!   the `socket` and `user` features;
//! - `nix::fcntl::Flock` for the single-instance lock, which requires `fs`;
//! - `nix::sys::signal::kill` for parent liveness, which requires `signal`.

use std::fs::{File, OpenOptions};
use std::os::unix::fs::OpenOptionsExt;
use std::os::unix::net::UnixStream;
use std::path::Path;

use anyhow::{Context, Result};
use nix::errno::Errno;
use nix::fcntl::{Flock, FlockArg};
use nix::sys::signal;
use nix::unistd::{getpeereid, getuid, Pid, Uid};

/// An exclusive `flock` that is released when dropped.
#[derive(Debug)]
pub struct InstanceLock {
    _inner: Flock<File>,
}

/// Try to take the single-instance lock at `path`.
///
/// Returns `Ok(None)` when another process already holds it, which the caller
/// reports as an already-running instance rather than as an error.
pub fn acquire_instance_lock(path: &Path) -> Result<Option<InstanceLock>> {
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .open(path)
        .with_context(|| format!("failed to open the instance lock {}", path.display()))?;

    match Flock::lock(file, FlockArg::LockExclusiveNonblock) {
        Ok(inner) => Ok(Some(InstanceLock { _inner: inner })),
        Err((_file, error)) if error == Errno::EWOULDBLOCK || error == Errno::EAGAIN => Ok(None),
        Err((_file, error)) => Err(error)
            .with_context(|| format!("failed to lock the instance lock {}", path.display())),
    }
}

/// The effective UID of the process on the other end of `stream`.
pub fn peer_uid(stream: &UnixStream) -> Result<Uid> {
    let (uid, _gid) =
        getpeereid(stream).context("failed to read the Unix socket peer credentials")?;
    Ok(uid)
}

/// This process's effective UID.
pub fn our_uid() -> Uid {
    getuid()
}

/// Whether a process with `pid` still exists.
///
/// A permission error means the process exists but belongs to another user, so
/// it is reported as alive. An unexpected error is also treated as alive: the
/// cost of waiting one more tick is lower than exiting while the parent lives.
pub fn process_alive(pid: i32) -> bool {
    match signal::kill(Pid::from_raw(pid), None) {
        Ok(()) => true,
        Err(Errno::ESRCH) => false,
        Err(_) => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn our_own_process_is_alive() {
        assert!(process_alive(std::process::id() as i32));
    }

    #[test]
    fn a_vanished_process_is_not_alive() {
        // `i32::MAX` is not a valid live pid on any supported platform.
        assert!(!process_alive(i32::MAX));
    }

    #[test]
    fn the_single_instance_lock_is_exclusive() {
        let directory = tempfile::tempdir().expect("temp dir");
        let path = directory.path().join("service.lock");

        let first = acquire_instance_lock(&path)
            .expect("first lock")
            .expect("acquired");
        assert!(
            acquire_instance_lock(&path)
                .expect("second attempt")
                .is_none(),
            "a second process must not acquire the lock"
        );
        drop(first);
        assert!(
            acquire_instance_lock(&path)
                .expect("third attempt")
                .is_some(),
            "the lock is released on drop"
        );
    }

    #[test]
    fn peer_uid_matches_our_uid_for_a_local_socket_pair() {
        let (first, second) = UnixStream::pair().expect("socket pair");
        assert_eq!(peer_uid(&first).expect("peer uid"), our_uid());
        assert_eq!(peer_uid(&second).expect("peer uid"), our_uid());
    }
}
