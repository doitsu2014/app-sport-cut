//! Shared test fixtures.
//!
//! Recordings are never committed: every fixture is generated with the local
//! media toolchain into a temporary directory, and every test skips (rather
//! than fails) when that toolchain is absent.

#![allow(dead_code)]

use std::path::{Path, PathBuf};
use std::process::Command;

use sportcut_media::MediaToolchain;

/// A temporary working directory plus the discovered media toolchain.
pub struct Fixtures {
    dir: tempfile::TempDir,
    pub toolchain: MediaToolchain,
}

/// Create a fixture set, or return `None` when the media toolchain is missing.
pub fn fixtures() -> Option<Fixtures> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            eprintln!("skipping test: {error}");
            return None;
        }
    };

    let dir = tempfile::tempdir().expect("temporary directory");
    Some(Fixtures { dir, toolchain })
}

impl Fixtures {
    /// Root of the temporary directory.
    pub fn root(&self) -> &Path {
        self.dir.path()
    }

    /// A path inside the temporary directory.
    pub fn path(&self, name: &str) -> PathBuf {
        self.dir.path().join(name)
    }

    /// Generate a video, optionally with a sine audio track.
    pub fn video(
        &self,
        name: &str,
        width: u32,
        height: u32,
        fps: u32,
        seconds: f64,
        with_audio: bool,
    ) -> PathBuf {
        let output = self.path(name);
        let mut command = Command::new(self.toolchain.ffmpeg());
        command.args(["-hide_banner", "-nostdin", "-y"]);
        command.args(["-f", "lavfi", "-i"]);
        command.arg(format!(
            "testsrc2=size={width}x{height}:rate={fps}:duration={seconds}"
        ));
        if with_audio {
            command.args(["-f", "lavfi", "-i"]);
            command.arg(format!("sine=frequency=440:duration={seconds}"));
        }
        command.args(["-c:v", "mpeg4", "-q:v", "5", "-pix_fmt", "yuv420p"]);
        if with_audio {
            command.args(["-c:a", "aac", "-b:a", "64k", "-shortest"]);
        } else {
            command.arg("-an");
        }
        command.arg(&output);

        let result = command.output().expect("run ffmpeg");
        assert!(
            result.status.success(),
            "fixture generation failed: {}",
            String::from_utf8_lossy(&result.stderr)
        );
        output
    }

    /// A file that looks like a video but is cut off before the moov atom.
    pub fn truncated(&self, name: &str, source: &Path) -> PathBuf {
        let bytes = std::fs::read(source).expect("read source video");
        let cut = bytes.len().min(2048);
        let output = self.path(name);
        std::fs::write(&output, &bytes[..cut]).expect("write truncated file");
        output
    }

    /// A file that is not media at all.
    pub fn text_file(&self, name: &str) -> PathBuf {
        let output = self.path(name);
        std::fs::write(&output, b"this is not a video\n").expect("write text file");
        output
    }

    /// A match directory inside the temporary directory.
    pub fn match_dir(&self, match_id: &str) -> sportcut_storage::MatchDirectory {
        sportcut_storage::MatchDirectory::new(self.dir.path().join(match_id))
    }
}

/// A cheap content hash used to prove a file did not change.
pub fn content_hash(path: &Path) -> u64 {
    let bytes = std::fs::read(path).expect("read file for hashing");
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in bytes {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

/// Progress sink that records every event it receives.
#[derive(Debug, Default)]
pub struct RecordingProgress {
    events: std::sync::Mutex<Vec<sportcut_common::ProgressEvent>>,
}

impl RecordingProgress {
    /// Events received so far.
    pub fn events(&self) -> Vec<sportcut_common::ProgressEvent> {
        self.events.lock().expect("progress mutex").clone()
    }
}

impl sportcut_common::ProgressSink for RecordingProgress {
    fn report(&self, event: sportcut_common::ProgressEvent) {
        self.events.lock().expect("progress mutex").push(event);
    }
}

/// Progress sink that cancels a token the first time it sees a given stage.
#[derive(Debug)]
pub struct CancelOnStage {
    pub token: sportcut_common::CancelToken,
    pub stage: &'static str,
}

impl sportcut_common::ProgressSink for CancelOnStage {
    fn report(&self, event: sportcut_common::ProgressEvent) {
        if event.stage == self.stage && event.value >= 1.0 {
            self.token.cancel();
        }
    }
}
