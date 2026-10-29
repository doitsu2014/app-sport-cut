//! Rendering an edit list with the local media toolchain.
//!
//! One `ffmpeg` pass reads the source once, splits it, trims a padded span per
//! clip, joins them in the requested order, composites the scoreboard the
//! application rendered, and mixes the music. Reading once rather than once per
//! clip is what keeps a reel of twenty points from decoding a match twenty times.
//!
//! The output is written to a `.part` file and renamed into place only after the
//! render succeeded, so a cancelled or failed export never replaces the reel the
//! user already had.

use std::ffi::OsString;
use std::path::{Path, PathBuf};

use sportcut_common::{CancelToken, ProgressEvent, ProgressSink, Result, SportcutError};
use sportcut_media::exec;
use sportcut_media::{probe, MediaMetadata, MediaToolchain};

use crate::edit_list::EditList;

/// Stage label for validating the list and reading the source.
pub const STAGE_PREPARE: &str = "prepare";
/// Stage label for the render itself.
pub const STAGE_RENDER: &str = "render";
/// Stage label for recording the finished file.
pub const STAGE_FINALIZE: &str = "finalize";

/// Every stage of an export, in order.
pub const STAGES: [&str; 3] = [STAGE_PREPARE, STAGE_RENDER, STAGE_FINALIZE];

/// Video codec for the development render path.
///
/// `mpeg4` is built into ffmpeg, so an LGPL-only build can render without
/// pulling in a GPL encoder such as x264. The shipping backend is
/// platform-native and will use the platform's hardware H.264 encoder; see
/// `docs/legal/dependency-register.md`.
const VIDEO_CODEC: &str = "mpeg4";

/// How long the reel fades out, when music is mixed in.
const MUSIC_FADE_SECONDS: f64 = 1.5;

/// Progress and cancellation for one render.
pub struct ExportContext<'a> {
    /// Cooperative cancellation signal.
    pub cancel: CancelToken,
    /// Where stage progress is reported.
    pub progress: &'a dyn ProgressSink,
}

impl std::fmt::Debug for ExportContext<'_> {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("ExportContext")
            .field("cancelled", &self.cancel.is_cancelled())
            .finish_non_exhaustive()
    }
}

/// What a render produced.
#[derive(Debug, Clone, PartialEq)]
pub struct RenderOutput {
    /// Path of the rendered reel.
    pub path: PathBuf,
    /// Size of the rendered file in bytes.
    pub size_bytes: u64,
    /// Duration of the reel in seconds.
    pub duration_seconds: f64,
    /// Number of clips in the reel.
    pub clip_count: usize,
}

/// Render an edit list to a single video file.
pub fn render(
    edit_list: &EditList,
    toolchain: &MediaToolchain,
    context: &ExportContext<'_>,
) -> Result<RenderOutput> {
    context.cancel.check()?;
    context
        .progress
        .report(ProgressEvent::new(STAGE_PREPARE, 0.0));

    let source = probe(&edit_list.source, toolchain)?;
    edit_list.validate(&source)?;
    let plan = RenderPlan::new(edit_list, &source)?;
    let inputs = InputLayout::new(edit_list);

    context
        .progress
        .report(ProgressEvent::new(STAGE_PREPARE, 1.0).with_message(format!(
            "{} clips, {:.1}s reel",
            plan.clips.len(),
            plan.total_seconds
        )));

    context.cancel.check()?;
    let partial = PartialFile::new(&edit_list.output)?;
    let graph = plan.filter_graph(edit_list, &source, &inputs);
    let args = plan.render_args(edit_list, &source, &inputs, &graph, &partial.path);

    context
        .progress
        .report(ProgressEvent::new(STAGE_RENDER, 0.0));
    let output = exec::run_with_progress(
        toolchain.ffmpeg(),
        "ffmpeg",
        &args,
        &edit_list.source,
        &context.cancel,
        &mut |line| {
            if let Some(value) = progress_seconds(line) {
                let fraction = (value / plan.total_seconds).clamp(0.0, 1.0);
                context
                    .progress
                    .report(ProgressEvent::new(STAGE_RENDER, fraction));
            }
        },
    )?;
    output
        .into_success("ffmpeg", &edit_list.source)
        .map_err(|error| match error {
            SportcutError::Cancelled => SportcutError::Cancelled,
            other => SportcutError::Artifact(format!("the render failed: {other}")),
        })?;

    context
        .progress
        .report(ProgressEvent::new(STAGE_RENDER, 1.0));

    context.cancel.check()?;
    context
        .progress
        .report(ProgressEvent::new(STAGE_FINALIZE, 0.0));
    let size_bytes = std::fs::metadata(&partial.path)
        .map_err(|error| SportcutError::io(&partial.path, error))?
        .len();
    if size_bytes == 0 {
        return Err(SportcutError::Artifact(format!(
            "the render produced an empty file at {}",
            partial.path.display()
        )));
    }
    std::fs::rename(&partial.path, &edit_list.output)
        .map_err(|error| SportcutError::io(&edit_list.output, error))?;
    context
        .progress
        .report(ProgressEvent::new(STAGE_FINALIZE, 1.0));

    Ok(RenderOutput {
        path: edit_list.output.clone(),
        size_bytes,
        duration_seconds: plan.total_seconds,
        clip_count: plan.clips.len(),
    })
}

/// Read the elapsed position out of one `-progress` line.
fn progress_seconds(line: &str) -> Option<f64> {
    let (key, value) = line.split_once('=')?;
    if key != "out_time_us" && key != "out_time_ms" {
        return None;
    }
    value
        .trim()
        .parse::<f64>()
        .ok()
        .map(|micros| micros / 1_000_000.0)
}

/// Which `ffmpeg` input each piece of the reel is read from.
///
/// The source is always input zero; everything after it exists only when the
/// list asks for it, so the indices are computed once instead of guessed at in
/// the filter graph.
#[derive(Debug, Clone)]
struct InputLayout {
    music: Option<usize>,
    /// Input index of each clip's overlay, `None` when the clip has none.
    clip_overlays: Vec<Option<usize>>,
    title: Option<usize>,
}

impl InputLayout {
    fn new(edit_list: &EditList) -> Self {
        let mut next = 1;
        let music = edit_list.has_music().then(|| {
            let index = next;
            next += 1;
            index
        });
        let clip_overlays = edit_list
            .clips
            .iter()
            .map(|clip| {
                clip.overlay.as_ref().map(|_| {
                    let index = next;
                    next += 1;
                    index
                })
            })
            .collect();
        let title = edit_list.title.as_ref().map(|_| {
            let index = next;
            next += 1;
            index
        });
        Self {
            music,
            clip_overlays,
            title,
        }
    }
}

#[derive(Debug, Clone)]
struct PlannedClip {
    /// Start of the padded span in the source recording, in seconds.
    start: f64,
    /// End of the padded span in the source recording, in seconds.
    end: f64,
}

#[derive(Debug, Clone)]
struct RenderPlan {
    clips: Vec<PlannedClip>,
    /// Duration of the title card, zero when there is none.
    title_seconds: f64,
    /// Duration of the whole reel.
    total_seconds: f64,
}

impl RenderPlan {
    fn new(edit_list: &EditList, source: &MediaMetadata) -> Result<Self> {
        let title_seconds = edit_list
            .title
            .as_ref()
            .map(|title| title.seconds)
            .unwrap_or(0.0);

        let mut clips = Vec::with_capacity(edit_list.clips.len());
        let mut total = title_seconds;
        for (index, clip) in edit_list.clips.iter().enumerate() {
            let (start, end) = edit_list.padded_span(clip, source.duration_seconds);
            if end <= start {
                return Err(SportcutError::InvalidInput(format!(
                    "clip {} has no material left inside the recording after padding",
                    index + 1
                )));
            }
            total += end - start;
            clips.push(PlannedClip { start, end });
        }

        Ok(Self {
            clips,
            title_seconds,
            total_seconds: total,
        })
    }

    fn filter_graph(
        &self,
        edit_list: &EditList,
        source: &MediaMetadata,
        inputs: &InputLayout,
    ) -> String {
        let mut graph = String::new();
        let count = self.clips.len();

        // --- video: one decode, trimmed, overlaid, joined --------------------
        if count == 1 {
            graph.push_str(&self.clip_chain(0, &self.clips[0], source, inputs));
        } else {
            graph.push_str(&format!("[0:v]split={count}"));
            for index in 0..count {
                graph.push_str(&format!("[v{index}]"));
            }
            graph.push(';');
            for (index, clip) in self.clips.iter().enumerate() {
                graph.push_str(&self.clip_chain(index, clip, source, inputs));
            }
            for index in 0..count {
                graph.push_str(&format!("[c{index}]"));
            }
            graph.push_str(&format!("concat=n={count}:v=1:a=0[clipsjoined];"));
        }

        let mut label = if count == 1 { "c0" } else { "clipsjoined" }.to_string();

        // --- title card ------------------------------------------------------
        if let Some(index) = inputs.title {
            graph.push_str(&format!(
                "[{index}:v]format=rgba,scale={}:{},fps={},format=yuv420p,\
                 setpts=PTS-STARTPTS[titlev];",
                even(source.width),
                even(source.height),
                frame_rate(source),
            ));
            graph.push_str(&format!("[titlev][{label}]concat=n=2:v=1:a=0[withtitle];"));
            label = "withtitle".to_string();
        }

        graph.push_str(&format!("[{label}]null[vout];"));

        // --- audio -----------------------------------------------------------
        let match_audio = if source.has_audio {
            let joined = if count == 1 {
                graph.push_str(&format!(
                    "[0:a]atrim=start={:.3}:end={:.3},asetpts=PTS-STARTPTS[joineda];",
                    self.clips[0].start, self.clips[0].end
                ));
                "joineda".to_string()
            } else {
                // `split` is video-only; audio is fanned out with `asplit`.
                graph.push_str(&format!("[0:a]asplit={count}"));
                for index in 0..count {
                    graph.push_str(&format!("[a{index}]"));
                }
                graph.push(';');
                for (index, clip) in self.clips.iter().enumerate() {
                    graph.push_str(&format!(
                        "[a{index}]atrim=start={:.3}:end={:.3},asetpts=PTS-STARTPTS[ac{index}];",
                        clip.start, clip.end
                    ));
                }
                for index in 0..count {
                    graph.push_str(&format!("[ac{index}]"));
                }
                graph.push_str(&format!("concat=n={count}:v=0:a=1[joineda];"));
                "joineda".to_string()
            };

            // The title card carries no source audio, so the match audio waits
            // for it and stays in step with the picture.
            if self.title_seconds > 0.0 {
                graph.push_str(&format!(
                    "[{joined}]adelay={}:all=1[shifteda];",
                    (self.title_seconds * 1000.0).round() as i64
                ));
                Some("shifteda".to_string())
            } else {
                Some(joined)
            }
        } else {
            None
        };

        let music = inputs.music.map(|index| {
            let fade_start = (self.total_seconds - MUSIC_FADE_SECONDS).max(0.0);
            let fade = MUSIC_FADE_SECONDS.min(self.total_seconds);
            graph.push_str(&format!(
                "[{index}:a]aformat=sample_rates=48000:sample_fmts=fltp:channel_layouts=stereo,\
                 volume={:.3},apad,atrim=0:{:.3},asetpts=N/SR/TB,\
                 afade=t=out:st={fade_start:.3}:d={fade:.3}[music];",
                edit_list.music_gain, self.total_seconds
            ));
            "music"
        });

        match (match_audio, music) {
            (Some(match_audio), Some(music)) => graph.push_str(&format!(
                "[{match_audio}][{music}]amix=inputs=2:duration=first:normalize=0[aout];"
            )),
            (Some(match_audio), None) => {
                graph.push_str(&format!("[{match_audio}]anull[aout];"));
            }
            (None, Some(music)) => {
                graph.push_str(&format!("[{music}]anull[aout];"));
            }
            (None, None) => {}
        }

        graph
    }

    /// One clip, from its trimmed source frames to the joined label `c{n}`.
    fn clip_chain(
        &self,
        index: usize,
        clip: &PlannedClip,
        source: &MediaMetadata,
        inputs: &InputLayout,
    ) -> String {
        let input = if self.clips.len() == 1 {
            "[0:v]".to_string()
        } else {
            format!("[v{index}]")
        };
        let trimmed = format!(
            "{input}trim=start={:.3}:end={:.3},setpts=PTS-STARTPTS,fps={},\
             scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[pre{index}];",
            clip.start,
            clip.end,
            frame_rate(source)
        );

        match inputs.clip_overlays.get(index).copied().flatten() {
            Some(overlay) => format!(
                "{trimmed}[{overlay}:v]format=rgba,scale={}:{}[ov{index}];\
                 [pre{index}][ov{index}]overlay=0:0:format=auto[c{index}];",
                even(source.width),
                even(source.height),
            ),
            None => format!("{trimmed}[pre{index}]null[c{index}];"),
        }
    }

    fn render_args(
        &self,
        edit_list: &EditList,
        source: &MediaMetadata,
        inputs: &InputLayout,
        graph: &str,
        part: &Path,
    ) -> Vec<OsString> {
        let mut args: Vec<OsString> = Vec::new();
        args.extend([
            OsString::from("-hide_banner"),
            OsString::from("-nostdin"),
            OsString::from("-y"),
            OsString::from("-i"),
        ]);
        args.push(edit_list.source.clone().into());

        if let Some(music) = &edit_list.music {
            args.push("-i".into());
            args.push(music.clone().into());
        }
        for clip in &edit_list.clips {
            if let Some(overlay) = &clip.overlay {
                args.push("-i".into());
                args.push(overlay.clone().into());
            }
        }
        if let (Some(title), Some(_)) = (&edit_list.title, inputs.title) {
            args.extend([
                OsString::from("-loop"),
                OsString::from("1"),
                OsString::from("-framerate"),
                OsString::from(frame_rate(source)),
                OsString::from("-t"),
                OsString::from(format!("{:.3}", title.seconds)),
                OsString::from("-i"),
            ]);
            args.push(title.image.clone().into());
        }

        args.push("-filter_complex".into());
        args.push(graph.into());
        args.push("-map".into());
        args.push("[vout]".into());

        let has_audio = source.has_audio || edit_list.has_music();
        if has_audio {
            args.push("-map".into());
            args.push("[aout]".into());
        }

        args.extend([
            "-c:v".into(),
            OsString::from(VIDEO_CODEC),
            "-q:v".into(),
            OsString::from("4"),
            "-pix_fmt".into(),
            OsString::from("yuv420p"),
        ]);
        if has_audio {
            args.extend([
                "-c:a".into(),
                OsString::from("aac"),
                "-b:a".into(),
                OsString::from("128k"),
            ]);
        } else {
            args.push("-an".into());
        }

        args.extend([
            "-movflags".into(),
            OsString::from("+faststart"),
            // The partial file is named `....mp4.part`, so the container has to
            // be named rather than inferred from the extension.
            "-f".into(),
            OsString::from("mp4"),
            "-progress".into(),
            OsString::from("pipe:1"),
            "-nostats".into(),
            "-loglevel".into(),
            OsString::from("error"),
        ]);
        args.push(part.into());
        args
    }
}

fn frame_rate(source: &MediaMetadata) -> String {
    if source.frame_rate.is_finite() && source.frame_rate > 0.1 {
        format!("{:.3}", source.frame_rate)
    } else {
        "30".to_string()
    }
}

fn even(value: u32) -> u32 {
    if value % 2 == 0 {
        value
    } else {
        value - 1
    }
}

/// The `.part` file one render writes into.
///
/// Dropping it removes the file, so a cancelled or failed render leaves nothing
/// behind. On success the file has already been renamed into place, which makes
/// the cleanup a no-op.
#[derive(Debug)]
struct PartialFile {
    path: PathBuf,
}

impl PartialFile {
    fn new(output: &Path) -> Result<Self> {
        if let Some(parent) = output.parent() {
            std::fs::create_dir_all(parent).map_err(|error| SportcutError::io(parent, error))?;
        }
        Ok(Self {
            path: PathBuf::from(format!("{}.part", output.display())),
        })
    }
}

impl Drop for PartialFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}
