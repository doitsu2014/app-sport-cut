//! The bridge contract, exercised through the facade the Flutter client calls.

use std::path::{Path, PathBuf};
use std::process::Command;

use sportcut_api::{
    job_status, match_manifest, probe_media, start_import, start_regenerate_match_media,
};
use sportcut_api::{JobStateDto, JobStatusDto, MediaImportRequestDto};
use sportcut_media::MediaToolchain;

/// Wait for a started job to reach a terminal state, the way the client polls.
fn await_job(job_id: &str) -> JobStatusDto {
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(120);
    loop {
        let status = job_status(job_id.to_string()).expect("job status");
        if matches!(
            status.state,
            JobStateDto::Completed | JobStateDto::Cancelled | JobStateDto::Failed
        ) {
            return status;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "job {job_id} never finished: {status:?}"
        );
        std::thread::sleep(std::time::Duration::from_millis(20));
    }
}

/// Serializes the tests in this file.
///
/// The job registry is process-wide — that is what makes "one heavy job at a
/// time" mean anything across calls — so two imports running at once are
/// rejected by design. Rust runs test functions as threads of one process, which
/// would otherwise look exactly like two simultaneous imports in one
/// application.
fn exclusive() -> std::sync::MutexGuard<'static, ()> {
    static LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
    LOCK.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

struct Lab {
    dir: tempfile::TempDir,
    toolchain: MediaToolchain,
}

fn lab() -> Option<Lab> {
    let toolchain = match MediaToolchain::discover() {
        Ok(toolchain) => toolchain,
        Err(error) => {
            eprintln!("skipping test: {error}");
            return None;
        }
    };
    Some(Lab {
        dir: tempfile::tempdir().expect("temp dir"),
        toolchain,
    })
}

impl Lab {
    fn path(&self, name: &str) -> PathBuf {
        self.dir.path().join(name)
    }

    fn video(&self, name: &str, seconds: f64, with_audio: bool) -> PathBuf {
        let output = self.path(name);
        let mut command = Command::new(self.toolchain.ffmpeg());
        command.args(["-hide_banner", "-nostdin", "-y"]);
        command.args(["-f", "lavfi", "-i"]);
        command.arg(format!("testsrc2=size=320x240:rate=10:duration={seconds}"));
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

    fn request(&self, video: &Path, match_id: &str) -> MediaImportRequestDto {
        MediaImportRequestDto {
            match_id: match_id.to_string(),
            original_path: video.to_string_lossy().to_string(),
            match_dir: self.path(match_id).to_string_lossy().to_string(),
            sampling_rate: 2.0,
        }
    }
}

#[test]
fn importing_through_the_facade_produces_the_contract_the_client_expects() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("client.mp4", 2.0, true);
    let request = lab.request(&video, "client-match");

    let probe = probe_media(request.original_path.clone()).expect("probe through the facade");
    assert!((probe.duration_seconds - 2.0).abs() < 0.5, "{probe:?}");
    assert!(probe.has_audio);
    assert_eq!(probe.width, 320);

    let handle = start_import(request.clone()).expect("start import");
    assert_eq!(handle.match_id, "client-match");

    // One heavy job at a time is now a property of the process, not of a single
    // call: while this import is admitted, another match's import is rejected
    // rather than queued or run alongside it.
    let rejected = start_import(lab.request(&video, "other-match"))
        .expect_err("a second heavy job must be rejected, not queued");
    assert!(
        rejected.to_string().contains("resource-intensive"),
        "{rejected}"
    );

    let job = await_job(&handle.job_id);
    assert_eq!(job.job_id, handle.job_id);
    assert_eq!(job.state, JobStateDto::Completed);
    assert_eq!(job.completed_stages.len(), 4);
    assert!(job.error.is_none());

    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    assert!(manifest.original_present);
    assert_eq!(manifest.artifacts.len(), 3);
    assert!(manifest.missing_kinds.is_empty());

    let kinds: Vec<&str> = manifest
        .artifacts
        .iter()
        .map(|artifact| artifact.kind.as_str())
        .collect();
    assert!(kinds.contains(&"proxy"), "{kinds:?}");
    assert!(kinds.contains(&"analysis_audio"), "{kinds:?}");
    assert!(kinds.contains(&"frames"), "{kinds:?}");

    // Importing again is a no-op: every stage is checkpointed as complete.
    let second = start_import(request.clone()).expect("second import");
    let second = await_job(&second.job_id);
    assert_eq!(second.state, JobStateDto::Completed);
    assert_eq!(second.completed_stages.len(), 4);
    assert_eq!(
        match_manifest(request.match_dir.clone())
            .expect("manifest after the second import")
            .artifacts
            .len(),
        3
    );
}

#[test]
fn a_match_missing_derived_artifacts_can_be_repaired_through_the_facade() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("repair.mp4", 2.0, true);
    let request = lab.request(&video, "repair-match");
    let handle = start_import(request.clone()).expect("initial import");
    assert_eq!(await_job(&handle.job_id).state, JobStateDto::Completed);

    // Move the derived artifacts aside, the way a user clearing space would.
    std::fs::rename(
        lab.path("repair-match/proxy"),
        lab.path("repair-match/proxy.removed"),
    )
    .expect("move proxy aside");
    std::fs::rename(
        lab.path("repair-match/frames"),
        lab.path("repair-match/frames.removed"),
    )
    .expect("move frames aside");

    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    assert_eq!(
        manifest.missing_kinds.len(),
        2,
        "{:?}",
        manifest.missing_kinds
    );
    assert!(manifest.missing_kinds.contains(&"proxy".to_string()));
    assert!(manifest.missing_kinds.contains(&"frames".to_string()));
    assert!(manifest.original_present);

    let repair =
        start_regenerate_match_media(request.match_dir.clone(), 2.0).expect("start regenerate");
    assert_eq!(await_job(&repair.job_id).state, JobStateDto::Completed);

    let repaired = match_manifest(request.match_dir.clone()).expect("repaired manifest");
    assert!(
        repaired.missing_kinds.is_empty(),
        "{:?}",
        repaired.missing_kinds
    );
    assert!(lab.path("repair-match/proxy/proxy.mp4").is_file());
    assert!(lab.path("repair-match/frames").is_dir());

    // A second repair is not swallowed by the checkpoint file: what to rebuild
    // is decided from the manifest, which again reports the moved artifacts.
    std::fs::rename(
        lab.path("repair-match/proxy"),
        lab.path("repair-match/proxy.removed-again"),
    )
    .expect("move proxy aside again");
    let again = start_regenerate_match_media(request.match_dir.clone(), 2.0)
        .expect("start second regenerate");
    assert_eq!(await_job(&again.job_id).state, JobStateDto::Completed);
    assert!(lab.path("repair-match/proxy/proxy.mp4").is_file());
}

#[test]
fn a_source_without_audio_imports_and_reports_no_analysis_audio() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("silent.mp4", 2.0, false);
    let request = lab.request(&video, "silent-match");

    let handle = start_import(request.clone()).expect("start a silent import");
    assert_eq!(await_job(&handle.job_id).state, JobStateDto::Completed);

    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    let kinds: Vec<&str> = manifest
        .artifacts
        .iter()
        .map(|artifact| artifact.kind.as_str())
        .collect();
    assert!(!kinds.contains(&"analysis_audio"), "{kinds:?}");
    assert!(kinds.contains(&"proxy"), "{kinds:?}");
    assert!(kinds.contains(&"frames"), "{kinds:?}");
}

#[test]
fn an_unreadable_source_surfaces_an_error_instead_of_a_partial_match() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let missing = lab.path("not-here.mp4");
    let error = probe_media(missing.to_string_lossy().to_string()).expect_err("must fail");
    assert!(error.to_string().contains("not-here.mp4"), "{error}");

    let request = MediaImportRequestDto {
        match_id: "broken-match".to_string(),
        original_path: missing.to_string_lossy().to_string(),
        match_dir: lab.path("broken-match").to_string_lossy().to_string(),
        sampling_rate: 1.0,
    };
    let handle = start_import(request).expect("the job starts; the stage is what fails");
    let failed = await_job(&handle.job_id);
    assert_eq!(failed.state, JobStateDto::Failed);
    let reason = failed.error.expect("a failure carries a reason");
    assert!(reason.contains("not-here.mp4"), "{reason}");
    assert!(!lab.path("broken-match/manifest.json").is_file());
}
