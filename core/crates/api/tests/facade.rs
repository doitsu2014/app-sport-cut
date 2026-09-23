//! The bridge contract, exercised through the facade the Flutter client calls.

use std::path::{Path, PathBuf};
use std::process::Command;

use sportcut_api::{import_media, match_manifest, probe_media, regenerate_match_media};
use sportcut_api::{JobStateDto, MediaImportRequestDto};
use sportcut_media::MediaToolchain;

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
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("client.mp4", 2.0, true);
    let request = lab.request(&video, "client-match");

    let probe = probe_media(request.original_path.clone()).expect("probe through the facade");
    assert!((probe.duration_seconds - 2.0).abs() < 0.5, "{probe:?}");
    assert!(probe.has_audio);
    assert_eq!(probe.width, 320);

    let result = import_media(request.clone()).expect("import through the facade");
    assert_eq!(result.job.state, JobStateDto::Completed);
    assert_eq!(result.job.completed_stages.len(), 4);
    assert!(result.job.error.is_none());
    assert!(result.frames_sampled > 0);
    assert!(
        result.skipped_stages.is_empty(),
        "{:?}",
        result.skipped_stages
    );
    assert!(result.manifest.original_present);
    assert_eq!(result.manifest.artifacts.len(), 3);
    assert!(result.manifest.missing_kinds.is_empty());

    let kinds: Vec<&str> = result
        .manifest
        .artifacts
        .iter()
        .map(|artifact| artifact.kind.as_str())
        .collect();
    assert!(kinds.contains(&"proxy"), "{kinds:?}");
    assert!(kinds.contains(&"analysis_audio"), "{kinds:?}");
    assert!(kinds.contains(&"frames"), "{kinds:?}");

    // Importing again is a no-op: every stage is checkpointed as complete.
    let second = import_media(request.clone()).expect("second import");
    assert_eq!(second.job.state, JobStateDto::Completed);
    assert_eq!(
        second.skipped_stages.len(),
        4,
        "{:?}",
        second.skipped_stages
    );
}

#[test]
fn a_match_missing_derived_artifacts_can_be_repaired_through_the_facade() {
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("repair.mp4", 2.0, true);
    let request = lab.request(&video, "repair-match");
    import_media(request.clone()).expect("initial import");

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

    let repaired = regenerate_match_media(request.match_dir.clone(), 2.0).expect("regenerate");
    assert!(
        repaired.missing_kinds.is_empty(),
        "{:?}",
        repaired.missing_kinds
    );
    assert!(lab.path("repair-match/proxy/proxy.mp4").is_file());
    assert!(lab.path("repair-match/frames").is_dir());
}

#[test]
fn a_source_without_audio_imports_and_reports_no_analysis_audio() {
    let Some(lab) = lab() else {
        return;
    };
    let video = lab.video("silent.mp4", 2.0, false);
    let request = lab.request(&video, "silent-match");

    let result = import_media(request).expect("import a silent recording");
    assert_eq!(result.job.state, JobStateDto::Completed);
    let kinds: Vec<&str> = result
        .manifest
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
    let error = import_media(request).expect_err("import must fail");
    assert!(error.to_string().contains("not-here.mp4"), "{error}");
    assert!(!lab.path("broken-match/manifest.json").is_file());
}
