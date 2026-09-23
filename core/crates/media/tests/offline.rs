//! The offline guarantee from the `media-pipeline` spec.
//!
//! Two checks: the whole pipeline completes with network access made
//! unreachable, and the crate contains no network dependency or API that could
//! reach out in the first place.

mod support;

use std::sync::Mutex;

use sportcut_media::{run, PipelineContext, PipelineOptions};
use support::fixtures;

const PROXY_ENV_VARS: [&str; 6] = [
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
];

/// Env changes are process-wide and the test harness is multi-threaded.
static ENV_LOCK: Mutex<()> = Mutex::new(());

#[test]
fn pipeline_completes_with_network_access_unavailable() {
    let Some(fixtures) = fixtures() else {
        return;
    };
    let video = fixtures.video("offline.mp4", 320, 240, 10, 2.0, true);
    let match_dir = fixtures.match_dir("offline-match");

    let _guard = ENV_LOCK.lock().expect("env lock");
    let saved: Vec<(&'static str, Option<String>)> = PROXY_ENV_VARS
        .iter()
        .map(|key| (*key, std::env::var(key).ok()))
        .collect();

    // Port 9 is the discard port and nothing is listening, so any attempt to
    // leave the machine would fail instead of silently succeeding.
    for key in PROXY_ENV_VARS {
        std::env::set_var(key, "http://127.0.0.1:9");
    }

    let result = run(
        &match_dir,
        &fixtures.toolchain,
        &PipelineOptions::new(&video).with_sampling_rate(2.0),
        &[],
        &PipelineContext::default(),
    );

    for (key, value) in saved {
        match value {
            Some(value) => std::env::set_var(key, value),
            None => std::env::remove_var(key),
        }
    }

    let report = result.expect("the media pipeline must not require network access");
    assert!(report.proxy.is_some());
    assert!(!report.frames.is_empty());
    assert!(match_dir.resolve("manifest.json").is_file());
}

#[test]
fn media_crate_contains_no_network_dependency_or_call() {
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let cargo_toml = std::fs::read_to_string(format!("{manifest_dir}/Cargo.toml"))
        .expect("read media Cargo.toml");

    for banned in [
        "reqwest",
        "hyper",
        "ureq",
        "isahc",
        "curl",
        "surf",
        "tokio",
        "async-std",
    ] {
        assert!(
            !cargo_toml.contains(banned),
            "the media crate must not depend on {banned}"
        );
    }

    let sources = collect_rust_files(&format!("{manifest_dir}/src"));
    assert!(!sources.is_empty(), "expected source files to audit");

    for path in sources {
        let source = std::fs::read_to_string(&path).expect("read source file");
        for banned in [
            "TcpStream",
            "UdpSocket",
            "std::net::",
            "reqwest::",
            "ureq::",
            "isahc::",
        ] {
            assert!(
                !source.contains(banned),
                "{} contains the network API {banned}",
                path.display()
            );
        }
    }
}

fn collect_rust_files(dir: &str) -> Vec<std::path::PathBuf> {
    let mut files = Vec::new();
    let mut stack = vec![std::path::PathBuf::from(dir)];
    while let Some(path) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&path) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path.extension().is_some_and(|extension| extension == "rs") {
                files.push(path);
            }
        }
    }
    files
}
