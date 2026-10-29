//! Fixtures for the render tests.
//!
//! Every recording, image, and audio track a render test needs is generated
//! with the local media toolchain into a temporary directory, and the tests
//! skip rather than fail when that toolchain is missing. Nothing is committed
//! and nothing is fetched.
//!
//! This crate has no test-only dependencies — `tempfile` belongs to the media
//! crate — so the temporary directory here is a small one of our own.

use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

use sportcut_common::{CancelToken, ProgressEvent, ProgressSink};
use sportcut_media::MediaToolchain;

/// Width and height of every fixture, and of a rendered reel.
pub const WIDTH: u32 = 320;
pub const HEIGHT: u32 = 240;

/// The opaque box the overlay fixture draws, in frame pixels.
///
/// The overlay is transparent everywhere else, so a rendered frame shows the
/// box where the scoreboard would be and the recording underneath it
/// everywhere else.
pub const BOX_X: u32 = 80;
pub const BOX_Y: u32 = 60;
pub const BOX_WIDTH: u32 = 160;
pub const BOX_HEIGHT: u32 = 120;

/// A temporary directory plus the discovered media toolchain.
pub struct Fixtures {
    dir: PathBuf,
    toolchain: MediaToolchain,
}

/// Distinguishes the directories of tests that run at the same moment.
///
/// The clock alone is not enough: on a machine whose clock has microsecond
/// resolution, two tests starting in the same microsecond would be handed the
/// same directory, and whichever finished first would delete the other's
/// fixtures out from under it.
static SEQUENCE: AtomicU64 = AtomicU64::new(0);

/// Create a fixture set, or `None` when the media toolchain is missing.
pub fn fixtures() -> Option<Fixtures> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            eprintln!("skipping test: {error}");
            return None;
        }
    };

    let unique = format!(
        "sportcut-render-{}-{}-{}",
        std::process::id(),
        SEQUENCE.fetch_add(1, Ordering::Relaxed),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("the clock is after the epoch")
            .as_nanos()
    );
    let dir = std::env::temp_dir().join(unique);
    std::fs::create_dir_all(&dir).expect("create the fixture directory");
    Some(Fixtures { dir, toolchain })
}

impl Drop for Fixtures {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

impl Fixtures {
    /// The media toolchain these fixtures were discovered with.
    pub fn toolchain(&self) -> &MediaToolchain {
        &self.toolchain
    }

    /// A path inside the temporary directory.
    pub fn path(&self, name: &str) -> PathBuf {
        self.dir.join(name)
    }

    /// Run a tool, failing the test with its diagnostic if it does not succeed.
    fn run(&self, tool: &Path, args: &[String]) -> String {
        let output = Command::new(tool)
            .args(args)
            .output()
            .unwrap_or_else(|error| panic!("could not run {}: {error}", tool.display()));
        assert!(
            output.status.success(),
            "{} failed: {}",
            tool.display(),
            String::from_utf8_lossy(&output.stderr)
        );
        String::from_utf8_lossy(&output.stdout).to_string()
    }

    /// Five seconds of solid colour: red for the first half, blue for the
    /// second, optionally with a tone.
    ///
    /// Two distinguishable halves are what lets a test say which clip a frame
    /// of the reel came from, and therefore that the clips are in the order the
    /// edit list asked for.
    pub fn two_colour_video(&self, name: &str, with_audio: bool) -> PathBuf {
        let output = self.path(name);
        let mut args = vec![
            "-hide_banner".to_string(),
            "-nostdin".to_string(),
            "-y".to_string(),
            "-f".to_string(),
            "lavfi".to_string(),
            "-i".to_string(),
            format!("color=c=red:s={WIDTH}x{HEIGHT}:r=10:d=2.5"),
            "-f".to_string(),
            "lavfi".to_string(),
            "-i".to_string(),
            format!("color=c=blue:s={WIDTH}x{HEIGHT}:r=10:d=2.5"),
        ];
        if with_audio {
            args.extend([
                "-f".to_string(),
                "lavfi".to_string(),
                "-i".to_string(),
                "sine=frequency=440:duration=5".to_string(),
            ]);
        }
        args.extend([
            "-filter_complex".to_string(),
            "[0:v][1:v]concat=n=2:v=1:a=0[v]".to_string(),
            "-map".to_string(),
            "[v]".to_string(),
            "-c:v".to_string(),
            "mpeg4".to_string(),
            "-q:v".to_string(),
            "4".to_string(),
            "-pix_fmt".to_string(),
            "yuv420p".to_string(),
        ]);
        if with_audio {
            args.extend([
                "-map".to_string(),
                "2:a".to_string(),
                "-c:a".to_string(),
                "aac".to_string(),
                "-b:a".to_string(),
                "96k".to_string(),
            ]);
        } else {
            args.push("-an".to_string());
        }
        args.push(output.to_string_lossy().to_string());

        self.run(self.toolchain.ffmpeg(), &args);
        output
    }

    /// A short music track, for the reel to mix under the match audio.
    pub fn music(&self, name: &str, seconds: f64) -> PathBuf {
        let output = self.path(name);
        self.run(
            self.toolchain.ffmpeg(),
            &[
                "-hide_banner".to_string(),
                "-nostdin".to_string(),
                "-y".to_string(),
                "-f".to_string(),
                "lavfi".to_string(),
                "-i".to_string(),
                format!("sine=frequency=880:duration={seconds}"),
                "-c:a".to_string(),
                "aac".to_string(),
                "-b:a".to_string(),
                "96k".to_string(),
                output.to_string_lossy().to_string(),
            ],
        );
        output
    }

    /// The overlay the application would draw: transparent, with one opaque box
    /// standing in for the scoreboard.
    pub fn overlay(&self, name: &str) -> PathBuf {
        let output = self.path(name);
        self.run(
            self.toolchain.ffmpeg(),
            &[
                "-hide_banner".to_string(),
                "-nostdin".to_string(),
                "-y".to_string(),
                "-f".to_string(),
                "lavfi".to_string(),
                "-i".to_string(),
                format!("color=c=black@0.0:s={WIDTH}x{HEIGHT},format=rgba"),
                "-f".to_string(),
                "lavfi".to_string(),
                "-i".to_string(),
                format!("color=c=red:s={BOX_WIDTH}x{BOX_HEIGHT}"),
                "-filter_complex".to_string(),
                format!("[0:v][1:v]overlay={BOX_X}:{BOX_Y}"),
                "-frames:v".to_string(),
                "1".to_string(),
                output.to_string_lossy().to_string(),
            ],
        );
        output
    }

    /// The title card the application would draw: one solid colour.
    pub fn title(&self, name: &str, colour: &str) -> PathBuf {
        let output = self.path(name);
        self.run(
            self.toolchain.ffmpeg(),
            &[
                "-hide_banner".to_string(),
                "-nostdin".to_string(),
                "-y".to_string(),
                "-f".to_string(),
                "lavfi".to_string(),
                "-i".to_string(),
                format!("color=c={colour}:s={WIDTH}x{HEIGHT}"),
                "-frames:v".to_string(),
                "1".to_string(),
                output.to_string_lossy().to_string(),
            ],
        );
        output
    }

    /// Duration of a file in seconds, as the probe reports it.
    pub fn duration(&self, path: &Path) -> f64 {
        let output = self.run(
            self.toolchain.ffprobe(),
            &[
                "-v".to_string(),
                "error".to_string(),
                "-show_entries".to_string(),
                "format=duration".to_string(),
                "-of".to_string(),
                "default=nw=1:nk=1".to_string(),
                path.to_string_lossy().to_string(),
            ],
        );
        output
            .trim()
            .parse()
            .unwrap_or_else(|error| panic!("{output:?} is not a duration: {error}"))
    }

    /// The stream kinds a file contains, for example `["video", "audio"]`.
    pub fn streams(&self, path: &Path) -> Vec<String> {
        let output = self.run(
            self.toolchain.ffprobe(),
            &[
                "-v".to_string(),
                "error".to_string(),
                "-show_entries".to_string(),
                "stream=codec_type".to_string(),
                "-of".to_string(),
                "default=nw=1:nk=1".to_string(),
                path.to_string_lossy().to_string(),
            ],
        );
        output
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect()
    }

    /// Average Y/U/V of one region of the frame shown at `seconds`.
    ///
    /// This is how a test sees what was actually encoded: the values come from
    /// the pixels of the file, not from an assumption about what the renderer
    /// asked for.
    pub fn region_stats(
        &self,
        path: &Path,
        seconds: f64,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) -> Stats {
        let output = self.run(
            self.toolchain.ffmpeg(),
            &[
                "-hide_banner".to_string(),
                "-nostdin".to_string(),
                "-ss".to_string(),
                format!("{seconds}"),
                "-i".to_string(),
                path.to_string_lossy().to_string(),
                "-frames:v".to_string(),
                "1".to_string(),
                "-vf".to_string(),
                format!("crop={width}:{height}:{x}:{y},signalstats,metadata=print:file=-"),
                "-f".to_string(),
                "null".to_string(),
                "-".to_string(),
            ],
        );

        let value = |key: &str| -> f64 {
            output
                .lines()
                .find_map(|line| {
                    line.trim()
                        .strip_prefix(&format!("lavfi.signalstats.{key}="))
                })
                .unwrap_or_else(|| panic!("{key} was not reported:\n{output}"))
                .parse()
                .unwrap_or_else(|error| panic!("{key} is not a number: {error}"))
        };
        Stats {
            y: value("YAVG"),
            u: value("UAVG"),
            v: value("VAVG"),
        }
    }

    /// Mean volume of a window of a file, in dB.
    pub fn mean_volume_db(&self, path: &Path, start: f64, seconds: f64) -> f64 {
        let output = Command::new(self.toolchain.ffmpeg())
            .args([
                "-hide_banner".to_string(),
                "-nostdin".to_string(),
                "-ss".to_string(),
                format!("{start}"),
                "-t".to_string(),
                format!("{seconds}"),
                "-i".to_string(),
                path.to_string_lossy().to_string(),
                "-af".to_string(),
                "volumedetect".to_string(),
                "-f".to_string(),
                "null".to_string(),
                "-".to_string(),
            ])
            .output()
            .expect("run ffmpeg");
        let stderr = String::from_utf8_lossy(&output.stderr);
        assert!(output.status.success(), "volumedetect failed: {stderr}");
        stderr
            .lines()
            .find_map(|line| {
                let (_, value) = line.trim().split_once("mean_volume:")?;
                value.trim().trim_end_matches(" dB").parse::<f64>().ok()
            })
            .unwrap_or_else(|| panic!("no mean volume was reported:\n{stderr}"))
    }
}

/// Average colour of a region of a frame.
#[derive(Debug, Clone, Copy)]
pub struct Stats {
    pub y: f64,
    pub u: f64,
    pub v: f64,
}

impl Stats {
    /// How red the region is: the red channel's difference from the blue one.
    pub fn redness(&self) -> f64 {
        self.v - self.u
    }
}

/// A cheap content hash, used to prove a file was not modified.
pub fn content_hash(path: &Path) -> u64 {
    let bytes = std::fs::read(path).expect("read the file for hashing");
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in bytes {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

/// Progress sink that records what it was told.
#[derive(Debug, Default)]
pub struct RecordingProgress {
    events: Mutex<Vec<ProgressEvent>>,
}

impl RecordingProgress {
    /// The events received so far.
    pub fn events(&self) -> Vec<ProgressEvent> {
        self.events.lock().expect("progress mutex").clone()
    }
}

impl ProgressSink for RecordingProgress {
    fn report(&self, event: ProgressEvent) {
        self.events.lock().expect("progress mutex").push(event);
    }
}

/// Progress sink that cancels the render as soon as it starts encoding.
///
/// Cancelling from the sink rather than from another thread is what makes the
/// cancelled-export test deterministic: the token flips at a known point in the
/// render, and the toolchain is stopped at its next check.
#[derive(Debug)]
pub struct CancelWhenEncoding {
    token: CancelToken,
    stage: &'static str,
}

impl CancelWhenEncoding {
    /// A sink that cancels once `stage` reports zero progress.
    pub fn new(token: CancelToken, stage: &'static str) -> Self {
        Self { token, stage }
    }
}

impl ProgressSink for CancelWhenEncoding {
    fn report(&self, event: ProgressEvent) {
        if event.stage == self.stage && event.value <= 0.0 {
            self.token.cancel();
        }
    }
}
