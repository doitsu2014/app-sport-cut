//! Caller-path validation, protocol §7.
//!
//! Caller-supplied paths are accepted only for the documented operations, and
//! each is canonicalized and checked against the root that operation owns. A
//! lexical `starts_with` is not enough: a symlink inside the root can point
//! anywhere, so an existing path is resolved before it is compared. A path
//! that does not exist yet (the import case) is resolved through its nearest
//! existing ancestor, so no unchecked component can hide a symlink.

use std::path::{Component, Path, PathBuf};

use crate::error::ProtocolError;
use crate::server::ServiceContext;

/// Validate that `raw` resolves under `root`.
///
/// `allow_missing` permits a path whose leaf does not exist yet, provided every
/// existing component resolves under the root.
pub fn under_root(
    root: &Path,
    raw: &str,
    label: &str,
    allow_missing: bool,
) -> Result<PathBuf, ProtocolError> {
    validate_absolute(raw, label)?;

    let canonical_root = std::fs::canonicalize(root).unwrap_or_else(|_| root.to_path_buf());
    let resolved = if std::fs::symlink_metadata(raw).is_ok() {
        std::fs::canonicalize(raw).map_err(|error| {
            ProtocolError::invalid_params(format!("{label} could not be resolved: {error}"))
        })?
    } else if allow_missing {
        canonicalize_lenient(Path::new(raw)).ok_or_else(|| {
            ProtocolError::invalid_params(format!("{label} could not be resolved"))
        })?
    } else {
        return Err(ProtocolError::invalid_params(format!(
            "{label} does not exist: {raw}"
        )));
    };

    if !resolved.starts_with(&canonical_root) {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must resolve under {}",
            canonical_root.display()
        )));
    }
    Ok(resolved)
}

/// Validate that `raw` resolves under one of `roots`.
pub fn under_any_root(
    roots: &[PathBuf],
    raw: &str,
    label: &str,
    allow_missing: bool,
) -> Result<PathBuf, ProtocolError> {
    validate_absolute(raw, label)?;
    let mut last_error = None;
    for root in roots {
        match under_root(root, raw, label, allow_missing) {
            Ok(path) => return Ok(path),
            Err(error) => last_error = Some(error),
        }
    }
    Err(last_error.unwrap_or_else(|| {
        ProtocolError::invalid_params(format!("{label} must resolve under a service-owned root"))
    }))
}

/// A recording the service owns: under `recordings/` or the inbox handoff.
pub fn recording(
    context: &ServiceContext,
    raw: &str,
    label: &str,
) -> Result<String, ProtocolError> {
    let roots = [
        context.state_root.join("recordings"),
        context.state_root.join("inbox"),
    ];
    under_any_root(&roots, raw, label, false).map(path_string)
}

/// A file under the service state root, such as an exported music track.
pub fn state_root_path(
    context: &ServiceContext,
    raw: &str,
    label: &str,
) -> Result<String, ProtocolError> {
    under_root(&context.state_root, raw, label, false).map(path_string)
}

/// A render input must live directly inside one allocated
/// `<state-root>/render-inputs/<uuid>/` directory.
pub fn render_input(
    context: &ServiceContext,
    raw: &str,
    label: &str,
) -> Result<String, ProtocolError> {
    let root = context.state_root.join("render-inputs");
    let resolved = under_root(&root, raw, label, false)?;
    let canonical_root = std::fs::canonicalize(&root).unwrap_or(root);
    let relative = resolved.strip_prefix(&canonical_root).map_err(|_| {
        ProtocolError::invalid_params(format!(
            "{label} must be inside an allocated render-inputs/<uuid>/ directory"
        ))
    })?;
    let mut components = relative.components();
    let Some(Component::Normal(uuid)) = components.next() else {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must be inside an allocated render-inputs/<uuid>/ directory"
        )));
    };
    if uuid.is_empty() || components.next().is_none() {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must name a file inside render-inputs/<uuid>/, not the directory itself"
        )));
    }
    Ok(path_string(resolved))
}

fn validate_absolute(raw: &str, label: &str) -> Result<(), ProtocolError> {
    if raw.trim().is_empty() {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must not be empty"
        )));
    }
    let path = Path::new(raw);
    if !path.is_absolute() {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must be an absolute path"
        )));
    }
    if path
        .components()
        .any(|component| matches!(component, Component::ParentDir))
    {
        return Err(ProtocolError::invalid_params(format!(
            "{label} must not contain parent-directory components"
        )));
    }
    Ok(())
}

/// Resolve `path` through its deepest existing ancestor.
fn canonicalize_lenient(path: &Path) -> Option<PathBuf> {
    let mut existing = path.to_path_buf();
    let mut tail: Vec<std::ffi::OsString> = Vec::new();
    loop {
        if let Ok(mut canonical) = std::fs::canonicalize(&existing) {
            for component in tail.iter().rev() {
                canonical.push(component);
            }
            return Some(canonical);
        }
        let name = existing.file_name()?.to_os_string();
        tail.push(name);
        existing = existing.parent()?.to_path_buf();
    }
}

fn path_string(path: PathBuf) -> String {
    path.to_string_lossy().into_owned()
}

#[cfg(test)]
mod tests {
    use std::os::unix::fs::symlink;

    use super::*;

    fn context(root: &Path) -> ServiceContext {
        ServiceContext::for_tests(root)
    }

    #[test]
    fn a_path_inside_the_root_is_accepted() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("recordings").join("match-1")).expect("mkdir");
        let file = root.join("recordings").join("match-1").join("clip.mp4");
        std::fs::write(&file, b"x").expect("write");

        let context = context(&root);
        let resolved = recording(&context, file.to_str().expect("utf8"), "originalPath")
            .expect("inside the recordings root");
        assert_eq!(
            resolved,
            std::fs::canonicalize(&file)
                .expect("canonical file")
                .to_string_lossy()
        );
    }

    #[test]
    fn a_path_outside_the_root_is_rejected() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("recordings")).expect("mkdir");
        let outside = directory.path().join("outside.mp4");
        std::fs::write(&outside, b"x").expect("write");

        let context = context(&root);
        let error = recording(&context, outside.to_str().expect("utf8"), "originalPath")
            .expect_err("outside the root");
        assert_eq!(error.code, sportcut_protocol::code::INVALID_PARAMS);
    }

    #[test]
    fn traversal_components_are_rejected() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("recordings")).expect("mkdir");
        let context = context(&root);

        let raw = format!("{}/recordings/../outside.mp4", root.display());
        let error = recording(&context, &raw, "originalPath").expect_err("traversal");
        assert!(
            error.message.contains("parent-directory"),
            "{}",
            error.message
        );
    }

    #[test]
    fn a_symlink_that_escapes_the_root_is_rejected() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("recordings")).expect("mkdir");
        let outside = directory.path().join("outside");
        std::fs::create_dir_all(&outside).expect("mkdir outside");
        let secret = outside.join("secret.mp4");
        std::fs::write(&secret, b"x").expect("write secret");
        let link = root.join("recordings").join("link.mp4");
        symlink(&secret, &link).expect("symlink");

        let context = context(&root);
        let error = recording(&context, link.to_str().expect("utf8"), "originalPath")
            .expect_err("a symlink out of the root");
        assert!(
            error.message.contains("must resolve under"),
            "{}",
            error.message
        );
    }

    #[test]
    fn a_missing_leaf_is_resolved_through_its_ancestor() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("matches")).expect("mkdir");
        let context = context(&root);

        let missing = root.join("matches").join("new-match");
        let resolved = under_root(
            &context.state_root,
            missing.to_str().expect("utf8"),
            "matchDir",
            true,
        )
        .expect("missing leaf under the root");
        assert!(resolved.starts_with(std::fs::canonicalize(&root).expect("canonical root")));
    }

    #[test]
    fn render_inputs_must_sit_in_an_allocated_uuid_directory() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        let allocated = root.join("render-inputs").join("0f6b0f3e");
        std::fs::create_dir_all(&allocated).expect("mkdir");
        let image = allocated.join("title.png");
        std::fs::write(&image, b"x").expect("write");
        let context = context(&root);

        assert_eq!(
            render_input(&context, image.to_str().expect("utf8"), "title.imagePath")
                .expect("allocated directory"),
            std::fs::canonicalize(&image)
                .expect("canonical image")
                .to_string_lossy()
        );

        let loose = root.join("render-inputs").join("loose.png");
        std::fs::write(&loose, b"x").expect("write");
        let error = render_input(&context, loose.to_str().expect("utf8"), "overlayPath")
            .expect_err("not inside a uuid directory");
        assert!(
            error.message.contains("render-inputs/<uuid>"),
            "{}",
            error.message
        );
    }

    #[test]
    fn paths_under_the_state_root_are_accepted_for_music() {
        let directory = tempfile::tempdir().expect("temp dir");
        let root = directory.path().join("state");
        std::fs::create_dir_all(root.join("music")).expect("mkdir");
        let music = root.join("music").join("theme.mp3");
        std::fs::write(&music, b"x").expect("write");
        let context = context(&root);
        assert!(state_root_path(&context, music.to_str().expect("utf8"), "musicPath").is_ok());
    }
}
