//! `sportcut-cli` — the headless harness for the engine.
//!
//! The difficult media work is developed and benchmarked here before any mobile
//! UI exists: probe a recording, build a proxy, extract analysis audio, sample
//! frames, run the whole import pipeline into a match directory, and inspect or
//! regenerate what is stored there.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use sportcut_common::SportcutError;
use sportcut_media::{
    extract_analysis_audio, generate_proxy, probe, regenerate_missing, run as run_pipeline,
    sample_frames, FrameSamplingOptions, MediaMetadata, MediaToolchain, PipelineContext,
    PipelineOptions, ProxyOptions,
};
use sportcut_storage::{ArtifactManifest, MatchDirectory};

/// Exit code used when a command fails.
const EXIT_FAILURE: u8 = 1;

#[derive(Debug, Parser)]
#[command(
    name = "sportcut-cli",
    version,
    about = "Headless harness for the Sportcut media engine",
    long_about = "Develops and benchmarks the Sportcut media pipeline on a workstation. \
                  Every command works on local files only."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Read media metadata from a local video file.
    Probe {
        /// Recording to inspect.
        input: PathBuf,
        /// Print the metadata as JSON.
        #[arg(long)]
        json: bool,
    },

    /// Generate a reduced-resolution analysis proxy. The original is untouched.
    Proxy {
        /// Recording to read.
        input: PathBuf,
        /// Proxy file to write.
        #[arg(long)]
        out: PathBuf,
    },

    /// Extract a low-bitrate analysis audio track.
    Audio {
        /// Recording to read.
        input: PathBuf,
        /// Audio file to write.
        #[arg(long)]
        out: PathBuf,
    },

    /// Sample timestamped frames from a proxy.
    Frames {
        /// Proxy or recording to read.
        #[arg(long)]
        input: PathBuf,
        /// Directory to write frames into.
        #[arg(long)]
        out: PathBuf,
        /// Sampling rate in frames per second.
        #[arg(long, default_value_t = 1.0)]
        rate: f64,
    },

    /// Run the whole media pipeline for one match into its artifact directory.
    Import {
        /// Recording to import; referenced in place, never copied.
        #[arg(long)]
        input: PathBuf,
        /// Match identifier; also the match directory name.
        #[arg(long)]
        match_id: String,
        /// Directory that holds all match directories.
        #[arg(long)]
        match_root: PathBuf,
        /// Frame sampling rate in frames per second.
        #[arg(long, default_value_t = 1.0)]
        rate: f64,
        /// Print the resulting manifest as JSON.
        #[arg(long)]
        json: bool,
    },

    /// Show a match manifest and which artifacts are missing.
    Inspect {
        /// The match directory to inspect.
        match_dir: PathBuf,
        /// Print the summary as JSON.
        #[arg(long)]
        json: bool,
    },

    /// Regenerate derived artifacts that are recorded but missing from disk.
    Regenerate {
        /// The match directory to repair.
        match_dir: PathBuf,
        /// Frame sampling rate in frames per second for regenerated frames.
        #[arg(long, default_value_t = 1.0)]
        rate: f64,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match run(cli) {
        Ok(()) => ExitCode::SUCCESS,
        Err(Failure::Message(message)) => {
            eprintln!("sportcut-cli: {message}");
            ExitCode::from(EXIT_FAILURE)
        }
    }
}

#[derive(Debug)]
enum Failure {
    Message(String),
}

fn run(cli: Cli) -> Result<(), Failure> {
    match cli.command {
        Command::Probe { input, json } => command_probe(&input, json),
        Command::Proxy { input, out } => command_proxy(&input, &out),
        Command::Audio { input, out } => command_audio(&input, &out),
        Command::Frames { input, out, rate } => command_frames(&input, &out, rate),
        Command::Import {
            input,
            match_id,
            match_root,
            rate,
            json,
        } => command_import(&input, &match_root, &match_id, rate, json),
        Command::Inspect { match_dir, json } => command_inspect(&match_dir, json),
        Command::Regenerate { match_dir, rate } => command_regenerate(&match_dir, rate),
    }
}

fn toolchain() -> Result<MediaToolchain, Failure> {
    MediaToolchain::discover().map_err(to_failure)
}

fn command_probe(input: &std::path::Path, json: bool) -> Result<(), Failure> {
    require_file(input)?;
    let metadata = probe(input, &toolchain()?).map_err(to_failure)?;

    if json {
        print_json(&metadata)?;
    } else {
        print_metadata(&metadata);
    }
    Ok(())
}

fn command_proxy(input: &std::path::Path, out: &std::path::Path) -> Result<(), Failure> {
    require_file(input)?;
    let output =
        generate_proxy(input, out, &toolchain()?, &ProxyOptions::default()).map_err(to_failure)?;
    println!(
        "proxy written: {} ({}x{}, {} bytes)",
        output.path.display(),
        output.width,
        output.height,
        output.size_bytes
    );
    Ok(())
}

fn command_audio(input: &std::path::Path, out: &std::path::Path) -> Result<(), Failure> {
    require_file(input)?;
    let toolchain = toolchain()?;
    let metadata = probe(input, &toolchain).map_err(to_failure)?;
    match extract_analysis_audio(input, out, &toolchain, &metadata).map_err(to_failure)? {
        Some(path) => println!("analysis audio written: {}", path.display()),
        None => println!("no audio track in the source; nothing to extract"),
    }
    Ok(())
}

fn command_frames(
    input: &std::path::Path,
    out: &std::path::Path,
    rate: f64,
) -> Result<(), Failure> {
    require_file(input)?;
    let toolchain = toolchain()?;
    let metadata = probe(input, &toolchain).map_err(to_failure)?;
    let frames = sample_frames(
        input,
        out,
        &toolchain,
        &FrameSamplingOptions { rate },
        &metadata,
    )
    .map_err(to_failure)?;

    match (frames.first(), frames.last()) {
        (Some(first), Some(last)) => println!(
            "{} frames written to {} (first at {} ms, last at {} ms)",
            frames.len(),
            out.display(),
            first.timestamp_ms,
            last.timestamp_ms
        ),
        _ => println!("no frames were sampled"),
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn command_import(
    input: &std::path::Path,
    match_root: &std::path::Path,
    match_id: &str,
    rate: f64,
    json: bool,
) -> Result<(), Failure> {
    require_file(input)?;
    if match_id.trim().is_empty() {
        return Err(Failure::Message("match id must not be empty".to_string()));
    }

    let match_dir = MatchDirectory::new(match_root.join(match_id));
    let report = run_pipeline(
        &match_dir,
        &toolchain()?,
        &PipelineOptions::new(input).with_sampling_rate(rate),
        &[],
        &PipelineContext::default(),
    )
    .map_err(to_failure)?;

    if json {
        print_json(&report.manifest)?;
    } else {
        print_metadata(&report.metadata);
        println!("match directory: {}", match_dir.root().display());
        match &report.proxy {
            Some(path) => println!("proxy: {}", path.display()),
            None => println!("proxy: not produced"),
        }
        match &report.audio {
            Some(path) => println!("analysis audio: {}", path.display()),
            None => println!("analysis audio: none (source has no audio track)"),
        }
        println!("frames: {}", report.frames.len());
        println!("artifacts recorded: {}", report.manifest.artifacts.len());
    }
    Ok(())
}

fn command_inspect(match_dir: &std::path::Path, json: bool) -> Result<(), Failure> {
    require_dir(match_dir)?;
    let directory = MatchDirectory::new(match_dir);
    let manifest_path = directory.manifest_path();
    if !manifest_path.is_file() {
        return Err(Failure::Message(format!(
            "no manifest at {}; import the recording first",
            manifest_path.display()
        )));
    }

    let manifest = ArtifactManifest::load(&manifest_path).map_err(to_failure)?;
    let summary = manifest.summarize(directory.root());

    if json {
        print_json(&summary)?;
    } else {
        println!("match: {}", summary.match_id);
        println!(
            "original: {} (present: {})",
            manifest.original.path, summary.original_present
        );
        println!("complete: {}", format_kinds(&summary.complete));
        println!("missing: {}", format_kinds(&summary.missing));
        println!("non-final: {}", format_kinds(&summary.non_final));
    }
    Ok(())
}

fn command_regenerate(match_dir: &std::path::Path, rate: f64) -> Result<(), Failure> {
    require_dir(match_dir)?;
    let directory = MatchDirectory::new(match_dir);
    let options = PipelineOptions::new(directory.root().join("unused")).with_sampling_rate(rate);
    let regenerated = regenerate_missing(
        &directory,
        &toolchain()?,
        &options,
        &PipelineContext::default(),
    )
    .map_err(to_failure)?;

    if regenerated.is_empty() {
        println!("nothing to regenerate");
    } else {
        println!("regenerated: {}", format_kinds(&regenerated));
    }
    Ok(())
}

fn print_metadata(metadata: &MediaMetadata) {
    println!("path: {}", metadata.path);
    println!("duration: {:.3} s", metadata.duration_seconds);
    println!("frame rate: {:.3} fps", metadata.frame_rate);
    println!(
        "resolution: {}x{} (display {}x{})",
        metadata.width,
        metadata.height,
        metadata.display_size().0,
        metadata.display_size().1
    );
    println!(
        "orientation: {:?} (rotation {} degrees)",
        metadata.orientation(),
        metadata.rotation_degrees
    );
    println!(
        "audio track: {}",
        if metadata.has_audio {
            "present"
        } else {
            "absent"
        }
    );
    println!("size: {} bytes", metadata.size_bytes);
}

fn format_kinds(kinds: &[sportcut_storage::ArtifactKind]) -> String {
    if kinds.is_empty() {
        return "none".to_string();
    }
    kinds
        .iter()
        .map(|kind| kind.to_string())
        .collect::<Vec<_>>()
        .join(", ")
}

fn print_json<T: serde::Serialize>(value: &T) -> Result<(), Failure> {
    let json = serde_json::to_string_pretty(value)
        .map_err(|error| Failure::Message(format!("could not serialize output: {error}")))?;
    println!("{json}");
    Ok(())
}

fn to_failure(error: SportcutError) -> Failure {
    Failure::Message(error.to_string())
}

fn require_file(path: &std::path::Path) -> Result<(), Failure> {
    if path.is_file() {
        Ok(())
    } else {
        Err(Failure::Message(format!(
            "input file not found: {}",
            path.display()
        )))
    }
}

fn require_dir(path: &std::path::Path) -> Result<(), Failure> {
    if path.is_dir() {
        Ok(())
    } else {
        Err(Failure::Message(format!(
            "match directory not found: {}",
            path.display()
        )))
    }
}
