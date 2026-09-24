//! The bridge contract, exercised through the facade the Flutter client calls.

use std::path::{Path, PathBuf};
use std::process::Command;

use sportcut_api::{
    court_geometry, job_cancel, job_status, match_calibration, match_manifest, probe_media,
    save_match_calibration, start_import, start_regenerate_match_media,
};
use sportcut_api::{
    ArtifactStateDto, CalibrationSaveRequestDto, CalibrationSegmentDto, CourtCalibrationDto,
    CourtCornerDto, CourtOrientationDto, JobHandleDto, JobStateDto, JobStatusDto,
    MediaImportRequestDto,
};
use sportcut_media::MediaToolchain;
use sportcut_storage::{ArtifactKind, ArtifactManifest, ArtifactState, MatchDirectory};

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

/// Start an import, waiting for the heavy-job slot to come free.
///
/// A job reports its terminal state a moment before its worker releases the
/// admission slot, so a caller that starts the next job the instant the last one
/// finished can be told another heavy job is still running. The wait is bounded,
/// so a slot that never came free would still fail the test.
fn start_import_when_admitted(request: MediaImportRequestDto) -> JobHandleDto {
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
    loop {
        match start_import(request.clone()) {
            Ok(handle) => return handle,
            Err(error) => {
                let message = error.to_string();
                if !message.contains("resource-intensive") || std::time::Instant::now() > deadline {
                    panic!("the following import was refused: {message}");
                }
                std::thread::sleep(std::time::Duration::from_millis(20));
            }
        }
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

/// A calibration covering the whole recording, in the order the user marks it.
fn calibration_request(
    match_dir: &Path,
    corners: [(f64, f64); 4],
    orientation: CourtOrientationDto,
) -> CalibrationSaveRequestDto {
    CalibrationSaveRequestDto {
        match_dir: match_dir.to_string_lossy().to_string(),
        calibration: CourtCalibrationDto {
            schema_version: 1,
            segments: vec![CalibrationSegmentDto {
                from_ms: 0,
                corners: corners
                    .iter()
                    .map(|(x, y)| CourtCornerDto { x: *x, y: *y })
                    .collect(),
                orientation,
            }],
        },
    }
}

/// The court the calibration tests mark: seen from behind a baseline, with the
/// near edge wider than the far one.
const TRAPEZOID: [(f64, f64); 4] = [(0.10, 0.90), (0.90, 0.90), (0.70, 0.40), (0.30, 0.40)];

/// Import a short fixture and hand back its request, so the test has a match
/// directory with a manifest to calibrate.
fn imported_match(lab: &Lab, name: &str) -> MediaImportRequestDto {
    let video = lab.video(&format!("{name}.mp4"), 2.0, true);
    let request = lab.request(&video, name);
    let handle = start_import(request.clone()).expect("import the fixture");
    assert_eq!(await_job(&handle.job_id).state, JobStateDto::Completed);
    request
}

#[test]
fn an_unknown_job_handle_is_reported_by_identifier() {
    let _exclusive = exclusive();

    let status = job_status("job-that-never-started".to_string()).expect_err("must fail");
    assert!(
        status.to_string().contains("no job job-that-never-started"),
        "{status}"
    );

    let cancel = job_cancel("job-that-never-started".to_string()).expect_err("must fail");
    assert!(
        cancel.to_string().contains("job-that-never-started"),
        "{cancel}"
    );
}

#[test]
fn a_cancelled_import_stops_and_leaves_nothing_final() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("cancel.mp4", 20.0, true);
    let request = lab.request(&video, "cancel-match");

    let handle = start_import(request.clone()).expect("start import");
    let asked = job_cancel(handle.job_id.clone()).expect("cancel the running job");
    // Cancellation is immediate from the client's side: the status that comes
    // back already reports the job as cancelled.
    assert_eq!(asked.state, JobStateDto::Cancelled, "{asked:?}");

    let job = await_job(&handle.job_id);
    assert_eq!(job.state, JobStateDto::Cancelled, "{job:?}");

    // Whatever the cancelled run had written by then is not a result.
    if lab.path("cancel-match/manifest.json").is_file() {
        let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
        for artifact in &manifest.artifacts {
            assert_ne!(
                artifact.state,
                ArtifactStateDto::Final,
                "a cancelled job left a final artifact: {artifact:?}"
            );
        }
    }
}

#[test]
fn a_conflicting_job_is_refused_by_name_and_the_slot_is_released() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("conflict.mp4", 20.0, true);
    let first = lab.request(&video, "conflict-match");
    let handle = start_import(first.clone()).expect("start the first import");

    // Another job for the same match is refused, naming why.
    let same_match = start_import(first.clone()).expect_err("a second job for the match");
    assert!(
        same_match
            .to_string()
            .contains("already running for this match"),
        "{same_match}"
    );

    // And a different match cannot run alongside the heavy job either.
    let other = lab.request(&video, "conflict-other");
    let elsewhere = start_import(other).expect_err("a second heavy job");
    assert!(
        elsewhere.to_string().contains("resource-intensive"),
        "{elsewhere}"
    );

    assert_eq!(await_job(&handle.job_id).state, JobStateDto::Completed);

    // The slot is free again once the first job finished.
    let after = start_import_when_admitted(lab.request(&video, "conflict-after"));
    assert_eq!(await_job(&after.job_id).state, JobStateDto::Completed);
}

#[test]
fn a_match_reports_no_calibration_until_one_is_saved() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let request = imported_match(&lab, "uncalibrated");

    let stored = match_calibration(request.match_dir.clone()).expect("read");
    assert!(
        stored.is_none(),
        "nothing was marked, so nothing is claimed"
    );

    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    assert!(
        manifest.not_rebuildable_kinds.is_empty(),
        "{:?}",
        manifest.not_rebuildable_kinds
    );
    assert!(
        !manifest
            .artifacts
            .iter()
            .any(|artifact| artifact.kind == "calibration"),
        "{:?}",
        manifest.artifacts
    );
}

#[test]
fn saving_a_calibration_writes_the_artifact_and_reads_back() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let request = imported_match(&lab, "calibrated");
    let match_dir = Path::new(&request.match_dir).to_path_buf();

    let saved = save_match_calibration(calibration_request(
        &match_dir,
        TRAPEZOID,
        CourtOrientationDto::Away,
    ))
    .expect("save the calibration");
    assert!(saved.changed, "the first calibration is a change");
    assert!(saved.invalidated_kinds.is_empty(), "{saved:?}");
    assert_eq!(saved.geometry.len(), 1);
    assert_eq!(saved.geometry[0].image_to_court.len(), 9);
    assert_eq!(saved.geometry[0].court_to_image.len(), 9);
    assert_eq!(saved.geometry[0].corners.len(), 4);
    assert_eq!(saved.geometry[0].net.len(), 2);

    // The file is in the match directory and the manifest records it as final.
    assert!(lab
        .path("calibrated/calibration/calibration.json")
        .is_file());
    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    let entry = manifest
        .artifacts
        .iter()
        .find(|artifact| artifact.kind == "calibration")
        .expect("the calibration is recorded");
    assert_eq!(entry.state, ArtifactStateDto::Final, "{entry:?}");
    assert_eq!(entry.relative_path, "calibration/calibration.json");
    assert!(manifest.missing_kinds.is_empty(), "{manifest:?}");

    // Reading it back gives the corners and orientation the user marked, and
    // the geometry is the same arithmetic the client asks for directly.
    let stored = match_calibration(request.match_dir.clone())
        .expect("read")
        .expect("a stored calibration");
    assert_eq!(stored.schema_version, 1);
    assert_eq!(stored.segments.len(), 1);
    assert_eq!(stored.segments[0].orientation, CourtOrientationDto::Away);
    assert_eq!(stored.segments[0].corners.len(), 4);
    assert!((stored.segments[0].corners[0].x - TRAPEZOID[0].0).abs() < 1e-12);

    let derived = court_geometry(stored.segments[0].clone()).expect("derive the geometry");
    assert_eq!(derived.image_to_court, saved.geometry[0].image_to_court);
    assert_eq!(derived.net, saved.geometry[0].net);
}

#[test]
fn saving_the_same_calibration_again_discards_nothing() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let request = imported_match(&lab, "recalibrated");
    let match_dir = Path::new(&request.match_dir).to_path_buf();

    save_match_calibration(calibration_request(
        &match_dir,
        TRAPEZOID,
        CourtOrientationDto::Away,
    ))
    .expect("first save");

    // A match that has tracks should lose them when the court changes: they are
    // positions in the old court and mean nothing in the new one.
    let directory = MatchDirectory::new(&request.match_dir);
    let manifest_path = directory.manifest_path();
    let mut manifest = ArtifactManifest::load(&manifest_path).expect("manifest");
    manifest.record_artifact(
        ArtifactKind::Tracks,
        "tracks/tracks.json",
        ArtifactState::Final,
        Some(64),
    );
    manifest.save(&manifest_path).expect("save manifest");

    let unchanged = save_match_calibration(calibration_request(
        &match_dir,
        TRAPEZOID,
        CourtOrientationDto::Away,
    ))
    .expect("save the same court again");
    assert!(!unchanged.changed, "the same court is not a change");
    assert!(
        unchanged.invalidated_kinds.is_empty(),
        "an unchanged court discards nothing: {unchanged:?}"
    );
    assert!(
        ArtifactManifest::load(&manifest_path)
            .expect("manifest")
            .artifacts
            .iter()
            .any(|entry| entry.kind == ArtifactKind::Tracks),
        "the tracks survived an unchanged court"
    );

    // Moving a corner does invalidate them, and the new court is what is read
    // back afterwards.
    let moved = [(0.10, 0.90), (0.90, 0.90), (0.70, 0.40), (0.22, 0.32)];
    let changed = save_match_calibration(calibration_request(
        &match_dir,
        moved,
        CourtOrientationDto::Away,
    ))
    .expect("save the edited court");
    assert!(changed.changed);
    assert_eq!(changed.invalidated_kinds, vec!["tracks".to_string()]);
    let manifest = ArtifactManifest::load(&manifest_path).expect("manifest");
    assert!(
        !manifest
            .artifacts
            .iter()
            .any(|entry| entry.kind == ArtifactKind::Tracks),
        "the tracks derived from the old court are gone: {:?}",
        manifest.artifacts
    );
    let stored = match_calibration(request.match_dir.clone())
        .expect("read")
        .expect("a stored calibration");
    assert!((stored.segments[0].corners[3].x - moved[3].0).abs() < 1e-12);
    assert!((stored.segments[0].corners[3].y - moved[3].1).abs() < 1e-12);
}

#[test]
fn a_missing_calibration_is_reported_as_needing_the_user() {
    let _exclusive = exclusive();
    let Some(lab) = lab() else {
        return;
    };
    let request = imported_match(&lab, "wiped");

    save_match_calibration(calibration_request(
        Path::new(&request.match_dir),
        TRAPEZOID,
        CourtOrientationDto::Away,
    ))
    .expect("save the calibration");

    // The user's own input is not something the engine can rebuild, so a wipe
    // that takes it away has to be reported back to the user rather than
    // counted as repaired.
    std::fs::remove_file(lab.path("wiped/calibration/calibration.json")).expect("wipe calibration");
    std::fs::rename(lab.path("wiped/frames"), lab.path("wiped/frames.removed"))
        .expect("wipe frames");

    let manifest = match_manifest(request.match_dir.clone()).expect("manifest");
    assert!(
        manifest.missing_kinds.contains(&"calibration".to_string()),
        "{:?}",
        manifest.missing_kinds
    );
    assert!(
        manifest.missing_kinds.contains(&"frames".to_string()),
        "{:?}",
        manifest.missing_kinds
    );
    assert_eq!(
        manifest.not_rebuildable_kinds,
        vec!["calibration".to_string()],
        "the engine can rebuild frames, not a calibration"
    );

    let repair =
        start_regenerate_match_media(request.match_dir.clone(), 2.0).expect("start the repair");
    assert_eq!(await_job(&repair.job_id).state, JobStateDto::Completed);

    let repaired = match_manifest(request.match_dir.clone()).expect("manifest");
    assert!(
        !repaired.missing_kinds.contains(&"frames".to_string()),
        "the frames were rebuilt: {:?}",
        repaired.missing_kinds
    );
    assert_eq!(
        repaired.not_rebuildable_kinds,
        vec!["calibration".to_string()],
        "the repair did not invent a court"
    );
    assert!(match_calibration(request.match_dir.clone())
        .expect("read")
        .is_none());
}
