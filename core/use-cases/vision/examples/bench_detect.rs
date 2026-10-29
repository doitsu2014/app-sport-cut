//! Headless latency/sanity benchmark for the macOS TFLite person detector.
//!
//! Usage:
//!   cargo run --example bench_detect -p sportcut-vision \
//!     --features macos-tflite-eval -- <runtime> <model> <frames-dir> [min-score] [max-frames]

use std::path::PathBuf;
use std::time::Instant;

use sportcut_vision::{decode_sampled_jpeg, PersonDetector, TflitePersonDetector};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        eprintln!("usage: bench_detect <runtime> <model> <frames-dir> [min-score] [max-frames]");
        std::process::exit(2);
    }
    let runtime = PathBuf::from(&args[1]);
    let model = PathBuf::from(&args[2]);
    let dir = PathBuf::from(&args[3]);
    let min_score: f32 = args.get(4).map(|s| s.parse()).transpose()?.unwrap_or(0.2);
    let max_frames: usize = args
        .get(5)
        .map(|s| s.parse())
        .transpose()?
        .unwrap_or(usize::MAX);

    let detector = TflitePersonDetector::open(&runtime, &model, min_score)?;

    let mut paths: Vec<PathBuf> = std::fs::read_dir(&dir)?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension().map_or(false, |ext| {
                ext.eq_ignore_ascii_case("jpg") || ext.eq_ignore_ascii_case("jpeg")
            })
        })
        .collect();
    paths.sort();
    paths.truncate(max_frames);

    let mut latencies = Vec::with_capacity(paths.len());
    let mut total_people = 0_usize;
    let mut frames_with_people = 0_usize;

    for (index, path) in paths.iter().enumerate() {
        let decoded = decode_sampled_jpeg(path, 0)?;
        let started = Instant::now();
        let detections = detector.detect(&decoded.view())?;
        let elapsed_ms = started.elapsed().as_millis();
        latencies.push(elapsed_ms as f64);
        total_people += detections.len();
        if !detections.is_empty() {
            frames_with_people += 1;
        }
        println!(
            "frame {index:4} {} {:>5} ms  {} detections",
            path.file_name().and_then(|n| n.to_str()).unwrap_or("?"),
            elapsed_ms,
            detections.len()
        );
    }

    if latencies.is_empty() {
        println!("no frames benchmarked");
        return Ok(());
    }
    latencies.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = latencies[latencies.len() / 2];
    let p95 = latencies[((latencies.len() as f64) * 0.95) as usize];
    let total_ms: f64 = latencies.iter().sum();
    println!(
        "frames={} median={median:.1}ms p95={p95:.1}ms total={total_ms:.0}ms people_total={total_people} frames_with_people={frames_with_people}",
        latencies.len()
    );
    Ok(())
}
