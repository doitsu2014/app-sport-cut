//! The 17 `engine.*` methods, protocol §5.
//!
//! Every handler is a thin adapter. It validates the wire parameters, resolves
//! the match directory the service owns, calls the matching `sportcut-api`
//! facade function, and converts the facade's DTOs to the protocol's camelCase
//! JSON. No engine logic is reimplemented here, and no second job registry is
//! created: start methods return the facade's handle, and the transport follows
//! that handle with `sportcut_api::job_status`.
//!
//! ## Path resolution
//!
//! Protocol §5 makes the wire use `matchId` and lets the service resolve the
//! artifact directory. Phase 1 has no catalog yet, so a match resolves to
//! `<state-root>/matches/<matchId>`. A development caller may pass `matchDir`
//! explicitly; it must be absolute and resolve under the state root. Recording
//! inputs likewise accept an explicit `originalPath`/`sourcePath`, otherwise the
//! service looks for the single file in `<state-root>/recordings/<matchId>`.

use std::path::PathBuf;

use serde::de::DeserializeOwned;
use serde::Serialize;
use serde_json::{json, Value};
use sportcut_api::{
    court_geometry, export_highlight, job_cancel, job_status, match_calibration, match_manifest,
    match_player_tracks, match_rally_suggestions, media_import_stages, probe_media,
    rank_highlights, save_match_calibration, serving_sides, start_import, start_player_tracking,
    start_rally_segmentation, start_regenerate_match_media, CalibrationSaveRequestDto,
    CalibrationSegmentDto, CourtCalibrationDto, EditClipDto, EditTitleDto, ExportRequestDto,
    HighlightRankingRequestDto, JobHandleDto, JobStateDto, JobStatusDto, MediaImportRequestDto,
    PlayerTrackWindowRequestDto, PlayerTrackingConfigDto, PlayerTrackingRequestDto,
    RallySegmentationConfigDto, RallySegmentationRequestDto, ServingSideRequestDto,
};
use sportcut_common::SportcutError;
use sportcut_protocol::method::{
    ENGINE_CALIBRATION_GET, ENGINE_CALIBRATION_SAVE, ENGINE_COURT_GEOMETRY, ENGINE_EXPORT_START,
    ENGINE_HIGHLIGHT_RANK, ENGINE_IMPORT_STAGES, ENGINE_IMPORT_START, ENGINE_JOB_CANCEL,
    ENGINE_JOB_STATUS, ENGINE_MANIFEST, ENGINE_PROBE, ENGINE_RALLY_START, ENGINE_RALLY_SUGGESTIONS,
    ENGINE_REGENERATE_START, ENGINE_SERVING_SIDES, ENGINE_TRACKING_START, ENGINE_TRACKS_WINDOW,
    JOB_PROGRESS, JOB_STATE,
};
use sportcut_protocol::{code, Notification, ServiceLimits};

use crate::error::ProtocolError;
use crate::paths;
use crate::server::ServiceContext;

/// Poll cadence for job notifications: 20 Hz, the coalescing ceiling in
/// protocol §9.1 and §10. One notification per poll can never exceed it.
pub const PROGRESS_INTERVAL: std::time::Duration = std::time::Duration::from_millis(50);

/// A job the transport should follow after it has written the start response.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JobFollow {
    /// Identifier accepted by `sportcut_api::job_status`.
    pub job_id: String,
    /// Match the job belongs to; reported on every notification.
    pub match_id: String,
}

/// A successful engine call: its JSON result and, for start methods, a job the
/// connection should follow.
#[derive(Debug)]
pub struct EngineReply {
    /// Result value, with the protocol's camelCase field names.
    pub result: Value,
    /// Present when the method started a job.
    pub follow: Option<JobFollow>,
}

impl EngineReply {
    fn plain(result: Value) -> Self {
        Self {
            result,
            follow: None,
        }
    }
}

/// Route one engine method to its facade call.
pub fn dispatch(
    context: &ServiceContext,
    method: &str,
    params: &Value,
) -> Result<EngineReply, ProtocolError> {
    match method {
        ENGINE_IMPORT_STAGES => Ok(EngineReply::plain(
            json!({ "stages": media_import_stages() }),
        )),
        ENGINE_PROBE => probe(context, params),
        ENGINE_IMPORT_START => import_start(context, params),
        ENGINE_REGENERATE_START => regenerate_start(context, params),
        ENGINE_RALLY_START => rally_start(context, params),
        ENGINE_RALLY_SUGGESTIONS => rally_suggestions(context, params),
        ENGINE_TRACKS_WINDOW => tracks_window(context, params),
        ENGINE_TRACKING_START => tracking_start(context, params),
        ENGINE_JOB_STATUS => job_status_method(params),
        ENGINE_HIGHLIGHT_RANK => highlight_rank(params),
        ENGINE_SERVING_SIDES => serving_sides_method(params),
        ENGINE_COURT_GEOMETRY => court_geometry_method(params),
        ENGINE_CALIBRATION_SAVE => calibration_save(context, params),
        ENGINE_CALIBRATION_GET => calibration_get(context, params),
        ENGINE_JOB_CANCEL => job_cancel_method(params),
        ENGINE_EXPORT_START => export_start(context, params),
        ENGINE_MANIFEST => manifest(context, params),
        _ => Err(ProtocolError::method_not_found(method)),
    }
}

fn probe(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let source = params
        .get("source")
        .and_then(Value::as_object)
        .ok_or_else(|| {
            ProtocolError::invalid_params(
                "source must be an object with a kind and value, for example \
                 {\"kind\":\"path\",\"value\":\"/recordings/clip.mp4\"}",
            )
        })?;
    let kind = source.get("kind").and_then(Value::as_str).unwrap_or("path");
    let value = source
        .get("value")
        .and_then(Value::as_str)
        .ok_or_else(|| ProtocolError::invalid_params("source.value must be a string"))?;

    let path = match kind {
        "path" => paths::recording(context, value, "source.value")?,
        "bookmark" => {
            return Err(ProtocolError::new(
                code::UNSUPPORTED,
                "security-scoped bookmarks are not supported by this build; pass the recording path instead",
            ))
        }
        other => {
            return Err(ProtocolError::invalid_params(format!(
                "source.kind {other:?} is not supported; use \"path\""
            )))
        }
    };

    let metadata = probe_media(path).map_err(|error| map_facade_error("engine.probe", error))?;
    dto_reply(&metadata)
}

fn import_start(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let request = MediaImportRequestDto {
        match_id: resolved.id.clone(),
        original_path: original_path_for(context, &resolved.id, "originalPath", params)?,
        match_dir: resolved.dir_string(),
        sampling_rate: sampling_rate(params)?,
    };
    let handle =
        start_import(request).map_err(|error| map_facade_error("engine.import.start", error))?;
    job_reply(handle)
}

fn regenerate_start(
    context: &ServiceContext,
    params: &Value,
) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let handle = start_regenerate_match_media(resolved.dir_string(), sampling_rate(params)?)
        .map_err(|error| map_facade_error("engine.regenerate.start", error))?;
    job_reply(handle)
}

fn rally_start(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let request = RallySegmentationRequestDto {
        match_dir: resolved.dir_string(),
        config: dto_field::<RallySegmentationConfigDto>(params, "config")?,
    };
    let handle = start_rally_segmentation(request)
        .map_err(|error| map_facade_error("engine.rally.start", error))?;
    job_reply(handle)
}

fn rally_suggestions(
    context: &ServiceContext,
    params: &Value,
) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let request = RallySegmentationRequestDto {
        match_dir: resolved.dir_string(),
        config: dto_field::<RallySegmentationConfigDto>(params, "config")?,
    };
    let suggestions = match_rally_suggestions(request)
        .map_err(|error| map_facade_error("engine.rally.suggestions", error))?;
    dto_reply(&suggestions)
}

fn tracks_window(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let start_seconds = finite_number(params, "startSeconds")?;
    let end_seconds = finite_number(params, "endSeconds")?;

    // Protocol §10: the advertised maximum is enforced, not merely published.
    let maximum = f64::from(ServiceLimits::default().track_window_max_seconds);
    if end_seconds - start_seconds > maximum {
        return Err(ProtocolError::invalid_params(format!(
            "the player-track window is {:.1}s; request a narrower window of at most {maximum:.0}s",
            end_seconds - start_seconds
        )));
    }

    let request = PlayerTrackWindowRequestDto {
        match_dir: resolved.dir_string(),
        start_seconds,
        end_seconds,
    };
    let tracks = match_player_tracks(request)
        .map_err(|error| map_facade_error("engine.tracks.window", error))?;
    dto_reply(&tracks)
}

fn tracking_start(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let runtime_path = optional_asset(context, params, "runtimePath")?;
    let model_path = optional_asset(context, params, "modelPath")?;
    let request = PlayerTrackingRequestDto {
        match_dir: resolved.dir_string(),
        config: dto_field::<PlayerTrackingConfigDto>(params, "config")?,
        runtime_path,
        model_path,
    };
    let handle = start_player_tracking(request)
        .map_err(|error| map_facade_error("engine.tracking.start", error))?;
    job_reply(handle)
}

fn job_status_method(params: &Value) -> Result<EngineReply, ProtocolError> {
    let status = job_status(required_string(params, "jobId")?)
        .map_err(|error| map_facade_error("engine.job.status", error))?;
    dto_reply(&status)
}

fn highlight_rank(params: &Value) -> Result<EngineReply, ProtocolError> {
    let request = dto_params::<HighlightRankingRequestDto>(params)?;
    let ranked = rank_highlights(request)
        .map_err(|error| map_facade_error("engine.highlight.rank", error))?;
    Ok(EngineReply::plain(
        json!({ "rallies": dto_values(&ranked)? }),
    ))
}

fn serving_sides_method(params: &Value) -> Result<EngineReply, ProtocolError> {
    let request = dto_params::<ServingSideRequestDto>(params)?;
    let sides =
        serving_sides(request).map_err(|error| map_facade_error("engine.servingSides", error))?;
    Ok(EngineReply::plain(
        json!({ "rallies": dto_values(&sides)? }),
    ))
}

fn court_geometry_method(params: &Value) -> Result<EngineReply, ProtocolError> {
    let segment = dto_field::<CalibrationSegmentDto>(params, "segment")?;
    let geometry = court_geometry(segment)
        .map_err(|error| map_facade_error("engine.court.geometry", error))?;
    dto_reply(&geometry)
}

fn calibration_save(
    context: &ServiceContext,
    params: &Value,
) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let request = CalibrationSaveRequestDto {
        match_dir: resolved.dir_string(),
        calibration: dto_field::<CourtCalibrationDto>(params, "calibration")?,
    };
    let saved = save_match_calibration(request)
        .map_err(|error| map_facade_error("engine.calibration.save", error))?;
    dto_reply(&saved)
}

fn calibration_get(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let calibration = match_calibration(resolved.dir_string())
        .map_err(|error| map_facade_error("engine.calibration.get", error))?;
    dto_reply(&calibration)
}

fn job_cancel_method(params: &Value) -> Result<EngineReply, ProtocolError> {
    let status = job_cancel(required_string(params, "jobId")?)
        .map_err(|error| map_facade_error("engine.job.cancel", error))?;
    dto_reply(&status)
}

fn export_start(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let mut clips = dto_field::<Vec<EditClipDto>>(params, "clips")?;
    if clips.is_empty() {
        return Err(ProtocolError::invalid_params(
            "clips must contain at least one clip",
        ));
    }
    for clip in &mut clips {
        if let Some(overlay) = clip.overlay_path.as_deref() {
            clip.overlay_path = Some(paths::render_input(
                context,
                overlay,
                "clips[].overlayPath",
            )?);
        }
    }

    let mut title = optional_dto_field::<EditTitleDto>(params, "title")?;
    if let Some(title) = title.as_mut() {
        title.image_path = paths::render_input(context, &title.image_path, "title.imagePath")?;
    }

    let music_path = match optional_string(params, "musicPath")? {
        Some(raw) => Some(paths::state_root_path(context, &raw, "musicPath")?),
        None => None,
    };

    let request = ExportRequestDto {
        match_id: resolved.id.clone(),
        match_dir: resolved.dir_string(),
        source_path: original_path_for(context, &resolved.id, "sourcePath", params)?,
        clips,
        lead_in_seconds: finite_number(params, "leadInSeconds")?,
        lead_out_seconds: finite_number(params, "leadOutSeconds")?,
        title,
        music_path,
        music_gain: finite_number(params, "musicGain")?,
    };
    let handle = export_highlight(request)
        .map_err(|error| map_facade_error("engine.export.start", error))?;
    job_reply(handle)
}

fn manifest(context: &ServiceContext, params: &Value) -> Result<EngineReply, ProtocolError> {
    let resolved = resolve_match(context, params)?;
    let manifest = match_manifest(resolved.dir_string())
        .map_err(|error| map_facade_error("engine.manifest", error))?;
    dto_reply(&manifest)
}

/// A start method's handle, plus the job the connection follows.
fn job_reply(handle: JobHandleDto) -> Result<EngineReply, ProtocolError> {
    let follow = JobFollow {
        job_id: handle.job_id.clone(),
        match_id: handle.match_id.clone(),
    };
    let mut reply = dto_reply(&handle)?;
    reply.follow = Some(follow);
    Ok(reply)
}

fn dto_reply<T: Serialize>(dto: &T) -> Result<EngineReply, ProtocolError> {
    Ok(EngineReply::plain(dto_values(dto)?))
}

fn dto_values<T: Serialize>(dto: &T) -> Result<Value, ProtocolError> {
    let value = serde_json::to_value(dto).map_err(|error| {
        ProtocolError::new(
            code::INTERNAL,
            format!("failed to serialize the engine result: {error}"),
        )
    })?;
    Ok(map_keys(value, to_camel_key))
}

fn dto_params<T: DeserializeOwned>(params: &Value) -> Result<T, ProtocolError> {
    serde_json::from_value(map_keys(params.clone(), to_snake_key))
        .map_err(|error| ProtocolError::invalid_params(format!("invalid params: {error}")))
}

fn dto_field<T: DeserializeOwned>(params: &Value, name: &str) -> Result<T, ProtocolError> {
    let converted = map_keys(params.clone(), to_snake_key);
    let value = converted
        .get(name)
        .ok_or_else(|| ProtocolError::invalid_params(format!("{name} is required")))?;
    serde_json::from_value(value.clone())
        .map_err(|error| ProtocolError::invalid_params(format!("{name} is invalid: {error}")))
}

fn optional_dto_field<T: DeserializeOwned>(
    params: &Value,
    name: &str,
) -> Result<Option<T>, ProtocolError> {
    let converted = map_keys(params.clone(), to_snake_key);
    match converted.get(name) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => serde_json::from_value(value.clone())
            .map(Some)
            .map_err(|error| ProtocolError::invalid_params(format!("{name} is invalid: {error}"))),
    }
}

fn required_string(params: &Value, name: &str) -> Result<String, ProtocolError> {
    params
        .get(name)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| ProtocolError::invalid_params(format!("{name} must be a non-empty string")))
}

fn optional_string(params: &Value, name: &str) -> Result<Option<String>, ProtocolError> {
    match params.get(name) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(value)) => Ok(Some(value.clone())),
        Some(_) => Err(ProtocolError::invalid_params(format!(
            "{name} must be a string when supplied"
        ))),
    }
}

fn finite_number(params: &Value, name: &str) -> Result<f64, ProtocolError> {
    let value = params
        .get(name)
        .and_then(Value::as_f64)
        .ok_or_else(|| ProtocolError::invalid_params(format!("{name} must be a finite number")))?;
    if !value.is_finite() {
        return Err(ProtocolError::invalid_params(format!(
            "{name} must be a finite number"
        )));
    }
    Ok(value)
}

fn sampling_rate(params: &Value) -> Result<f64, ProtocolError> {
    let rate = finite_number(params, "samplingRate")?;
    if rate <= 0.0 {
        return Err(ProtocolError::invalid_params(
            "samplingRate must be greater than zero",
        ));
    }
    Ok(rate)
}

fn optional_asset(
    context: &ServiceContext,
    params: &Value,
    name: &str,
) -> Result<Option<String>, ProtocolError> {
    match optional_string(params, name)? {
        Some(raw) => Ok(Some(paths::asset(context, &raw, name)?)),
        None => Ok(None),
    }
}

struct ResolvedMatch {
    id: String,
    dir: PathBuf,
}

impl ResolvedMatch {
    fn dir_string(&self) -> String {
        self.dir.to_string_lossy().into_owned()
    }
}

/// Resolve `<state-root>/matches/<matchId>`, honouring a checked `matchDir`.
fn resolve_match(context: &ServiceContext, params: &Value) -> Result<ResolvedMatch, ProtocolError> {
    let id = required_string(params, "matchId")?;
    validate_match_id(&id)?;

    let dir = match params.get("matchDir") {
        None | Some(Value::Null) => context.state_root.join("matches").join(&id),
        Some(Value::String(raw)) => {
            // Protocol §5: `matchDir` is a development affordance only. A
            // release build resolves every match from the state root.
            if !cfg!(debug_assertions) {
                return Err(ProtocolError::invalid_params(
                    "matchDir is only accepted in development builds; pass matchId instead",
                ));
            }
            paths::under_root(&context.state_root, raw, "matchDir", true)?
        }
        Some(_) => {
            return Err(ProtocolError::invalid_params(
                "matchDir must be a string when supplied",
            ))
        }
    };

    Ok(ResolvedMatch { id, dir })
}

fn validate_match_id(id: &str) -> Result<(), ProtocolError> {
    if id.len() > 128 {
        return Err(ProtocolError::invalid_params(
            "matchId must be at most 128 bytes",
        ));
    }
    if id == "." || id == ".." || id.chars().any(|character| character.is_control()) {
        return Err(ProtocolError::invalid_params(
            "matchId contains a character the service cannot store",
        ));
    }
    if id.contains(['/', '\\']) {
        return Err(ProtocolError::invalid_params(
            "matchId must not contain a path separator",
        ));
    }
    Ok(())
}

/// An explicit input path, or the single file in the service recording store.
fn original_path_for(
    context: &ServiceContext,
    match_id: &str,
    field: &str,
    params: &Value,
) -> Result<String, ProtocolError> {
    if let Some(value) = params.get(field) {
        let raw = value
            .as_str()
            .ok_or_else(|| ProtocolError::invalid_params(format!("{field} must be a string")))?;
        return paths::recording(context, raw, field);
    }
    stored_recording(context, match_id)
}

fn stored_recording(context: &ServiceContext, match_id: &str) -> Result<String, ProtocolError> {
    let directory = context.state_root.join("recordings").join(match_id);
    let entries = std::fs::read_dir(&directory).map_err(|error| {
        ProtocolError::new(
            code::NOT_FOUND,
            format!(
                "no recording is stored for match {match_id} in {}: {error}",
                directory.display()
            ),
        )
    })?;

    let mut files = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|error| {
            ProtocolError::new(
                code::IO,
                format!("failed to read {}: {error}", directory.display()),
            )
        })?;
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if name.starts_with('.') || name.ends_with(".part") {
            continue;
        }
        let path = entry.path();
        if path.is_file() {
            files.push(path);
        }
    }

    match files.len() {
        1 => Ok(files.remove(0).to_string_lossy().into_owned()),
        0 => Err(ProtocolError::new(
            code::NOT_FOUND,
            format!(
                "no recording is stored for match {match_id}; import the match before analysis"
            ),
        )),
        _ => Err(ProtocolError::new(
            code::CONFLICT,
            format!(
                "match {match_id} has more than one stored recording; the service cannot choose one"
            ),
        )),
    }
}

/// Map a facade failure to the protocol's stable code and user-safe message.
///
/// The facade now preserves its typed [`SportcutError`], so the stable code is
/// chosen by variant rather than by matching diagnostic text. Errors created as
/// plain `anyhow` messages (mostly argument validation inside the facade) keep
/// a conservative text fallback, but the protocol code is never inferred from a
/// path or feature name that happens to contain a keyword.
pub fn map_facade_error(label: &str, error: anyhow::Error) -> ProtocolError {
    let message = format!("{error:#}");

    if let Some(typed) = error.downcast_ref::<SportcutError>() {
        return map_typed_error(label, typed, &message);
    }

    let lower = message.to_lowercase();
    let mapped = if lower.contains("no job ") && lower.contains("is known") {
        code::JOB_NOT_FOUND
    } else if lower.contains("was rejected")
        || lower.contains("resource-intensive")
        || lower.contains("already running for this match")
    {
        code::JOB_REJECTED
    } else if lower.contains("media toolchain unavailable")
        || lower.contains("was not found on path")
        || lower.contains("is not an executable file")
    {
        code::TOOLCHAIN_UNAVAILABLE
    } else if lower.contains("failed for") && lower.contains("exit status") {
        code::MEDIA_FAILED
    } else if lower.contains("could not read media metadata") {
        code::PROBE_FAILED
    } else if lower.contains("failed during stage") {
        code::JOB_FAILED
    } else if lower.contains("cancelled") {
        code::CANCELLED
    } else if lower.contains("must not be empty")
        || lower.contains("must be greater than zero")
        || lower.contains("finite")
        || lower.contains("invalid params")
    {
        code::INVALID_PARAMS
    } else if lower.contains("runtime is unavailable in this build") {
        code::UNSUPPORTED
    } else if lower.contains("artifact error")
        || lower.contains("player tracks")
        || lower.contains("court calibration")
        || lower.contains("track artifact")
        || lower.contains("manifest")
    {
        code::ARTIFACT
    } else if label == "engine.probe" {
        code::PROBE_FAILED
    } else {
        code::INTERNAL
    };

    let mut protocol_error = ProtocolError::new(mapped, format!("{label}: {message}"));
    if mapped == code::JOB_REJECTED {
        if let Some(running) = first_parenthesized(&message) {
            protocol_error =
                protocol_error.with_data_member("details", json!({ "runningJobId": running }));
        }
    }
    protocol_error
}

fn map_typed_error(label: &str, error: &SportcutError, message: &str) -> ProtocolError {
    let mapped = match error {
        SportcutError::Io { .. } => code::IO,
        SportcutError::InvalidInput(_) => code::INVALID_PARAMS,
        SportcutError::Unsupported { .. } => code::UNSUPPORTED,
        SportcutError::ToolchainUnavailable(_) => code::TOOLCHAIN_UNAVAILABLE,
        SportcutError::MediaToolFailed { .. } => code::MEDIA_FAILED,
        SportcutError::Probe { .. } => code::PROBE_FAILED,
        SportcutError::Artifact(_) => code::ARTIFACT,
        SportcutError::JobRejected { .. } => code::JOB_REJECTED,
        SportcutError::JobFailed { .. } => code::JOB_FAILED,
        SportcutError::Cancelled => code::CANCELLED,
    };

    let mut protocol_error = ProtocolError::new(mapped, format!("{label}: {message}"));
    if mapped == code::JOB_REJECTED {
        if let Some(running) = first_parenthesized(message) {
            protocol_error =
                protocol_error.with_data_member("details", json!({ "runningJobId": running }));
        }
    }
    protocol_error
}

fn first_parenthesized(message: &str) -> Option<&str> {
    let start = message.find('(')? + 1;
    let rest = &message[start..];
    let end = rest.find(')')?;
    let candidate = rest[..end].trim();
    (!candidate.is_empty()).then_some(candidate)
}

/// Whether a job state is terminal.
pub fn is_terminal(state: JobStateDto) -> bool {
    matches!(
        state,
        JobStateDto::Completed | JobStateDto::Cancelled | JobStateDto::Failed
    )
}

/// The `job.progress` notification for a non-terminal job.
pub fn progress_notification(status: &JobStatusDto, seq: u64) -> Notification {
    let progress = status.progress.as_ref();
    Notification::new(
        JOB_PROGRESS,
        json!({
            "jobId": status.job_id.clone(),
            "matchId": status.match_id.clone(),
            "state": status.state,
            "stage": status.stage.clone(),
            "value": progress.map_or(0.0, |progress| progress.value),
            "message": progress.and_then(|progress| progress.message.clone()),
            "seq": seq,
            "completedStages": status.completed_stages.clone(),
        }),
    )
}

/// The terminal `job.state` notification.
pub fn state_notification(status: &JobStatusDto, seq: u64) -> Notification {
    Notification::new(
        JOB_STATE,
        json!({
            "jobId": status.job_id.clone(),
            "matchId": status.match_id.clone(),
            "state": status.state,
            "stage": status.stage.clone(),
            "error": status.error.clone(),
            "completedStages": status.completed_stages.clone(),
            "seq": seq,
        }),
    )
}

fn to_snake_key(key: &str) -> String {
    let mut snake = String::with_capacity(key.len() + 4);
    for character in key.chars() {
        if character.is_ascii_uppercase() {
            snake.push('_');
            snake.push(character.to_ascii_lowercase());
        } else {
            snake.push(character);
        }
    }
    snake
}

fn to_camel_key(key: &str) -> String {
    let mut camel = String::with_capacity(key.len());
    let mut uppercase_next = false;
    for character in key.chars() {
        if character == '_' {
            uppercase_next = true;
        } else if uppercase_next {
            camel.push(character.to_ascii_uppercase());
            uppercase_next = false;
        } else {
            camel.push(character);
        }
    }
    camel
}

fn map_keys(value: Value, convert: fn(&str) -> String) -> Value {
    match value {
        Value::Object(map) => Value::Object(
            map.into_iter()
                .map(|(key, value)| (convert(&key), map_keys(value, convert)))
                .collect(),
        ),
        Value::Array(items) => Value::Array(
            items
                .into_iter()
                .map(|item| map_keys(item, convert))
                .collect(),
        ),
        other => other,
    }
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use serde_json::json;

    use super::*;

    fn context() -> ServiceContext {
        ServiceContext::for_tests(Path::new("/state"))
    }

    fn call(method: &str, params: Value) -> Result<EngineReply, ProtocolError> {
        dispatch(&context(), method, &params)
    }

    #[test]
    fn serving_sides_is_a_pure_engine_call_over_camel_case_dtos() {
        let reply = call(
            ENGINE_SERVING_SIDES,
            json!({
                "rallies": [
                    { "rallyId": "rally-1", "winner": "left" },
                    { "rallyId": "rally-2", "winner": "right" },
                    { "rallyId": "rally-3" }
                ]
            }),
        )
        .expect("serving sides");

        assert_eq!(
            reply.result,
            json!({
                "rallies": [
                    { "rallyId": "rally-1", "side": null },
                    { "rallyId": "rally-2", "side": "left" },
                    { "rallyId": "rally-3", "side": "right" }
                ]
            })
        );
        assert!(reply.follow.is_none());
    }

    #[test]
    fn highlight_rank_is_a_pure_engine_call_over_camel_case_dtos() {
        let reply = call(
            ENGINE_HIGHLIGHT_RANK,
            json!({
                "rallies": [
                    {
                        "rallyId": "short",
                        "startSeconds": 0.0,
                        "endSeconds": 2.0,
                        "motion": 0.1,
                        "scoreContext": 0.1
                    },
                    {
                        "rallyId": "long",
                        "startSeconds": 10.0,
                        "endSeconds": 40.0,
                        "motion": 1.0,
                        "scoreContext": 1.0
                    }
                ]
            }),
        )
        .expect("rank highlights");

        let rallies = reply.result["rallies"]
            .as_array()
            .expect("the result wraps its rallies");
        assert_eq!(rallies.len(), 2);
        assert_eq!(rallies[1]["rallyId"], "long");
        assert_eq!(rallies[1]["rank"], 1);
        assert_eq!(rallies[0]["rallyId"], "short");
        assert_eq!(rallies[0]["rank"], 2);
        assert!(
            rallies[1]["score"].as_f64().expect("score")
                > rallies[0]["score"].as_f64().expect("score")
        );
    }

    #[test]
    fn import_stages_reports_the_facade_list() {
        let reply = call(ENGINE_IMPORT_STAGES, json!({})).expect("stages");
        assert_eq!(
            reply.result,
            json!({ "stages": ["probe", "proxy", "audio", "frames"] })
        );
    }

    #[test]
    fn invalid_params_are_rejected_before_the_facade_is_called() {
        let error = call(ENGINE_SERVING_SIDES, json!({ "rallies": "not a list" }))
            .expect_err("malformed rallies");
        assert_eq!(error.code, code::INVALID_PARAMS);

        let error = call(ENGINE_MANIFEST, json!({})).expect_err("missing matchId");
        assert_eq!(error.code, code::INVALID_PARAMS);

        let error = call(
            ENGINE_COURT_GEOMETRY,
            json!({ "segment": { "fromMs": 0, "corners": [], "orientation": "away" } }),
        )
        .expect_err("invalid court");
        assert_eq!(error.code, code::INVALID_PARAMS);
    }

    #[test]
    fn an_unknown_method_is_not_found() {
        let error = call("engine.start.doesNotExist", json!({})).expect_err("unknown method");
        assert_eq!(error.code, code::METHOD_NOT_FOUND);
        assert_eq!(error.data()["kind"], json!("method_not_found"));
    }

    #[test]
    fn status_of_an_unknown_job_is_job_not_found() {
        let error = call(
            ENGINE_JOB_STATUS,
            json!({ "jobId": "job-that-never-started" }),
        )
        .expect_err("unknown job");
        assert_eq!(error.code, code::JOB_NOT_FOUND);
        assert!(
            error.message.contains("job-that-never-started"),
            "{}",
            error.message
        );
    }

    #[test]
    fn progress_and_state_notifications_serialize_the_documented_fields() {
        let status = JobStatusDto {
            job_id: "job-1".to_string(),
            match_id: "match-1".to_string(),
            state: JobStateDto::Running,
            stage: Some("proxy".to_string()),
            progress: Some(sportcut_api::JobProgressDto {
                stage: "proxy".to_string(),
                value: 0.42,
                message: Some("encoding proxy".to_string()),
            }),
            error: None,
            completed_stages: vec!["probe".to_string()],
        };

        let progress = serde_json::to_value(progress_notification(&status, 17)).expect("progress");
        assert_eq!(
            progress,
            json!({
                "jsonrpc": "2.0",
                "method": "job.progress",
                "params": {
                    "jobId": "job-1",
                    "matchId": "match-1",
                    "state": "running",
                    "stage": "proxy",
                    "value": 0.42,
                    "message": "encoding proxy",
                    "seq": 17,
                    "completedStages": ["probe"]
                }
            })
        );

        let terminal = JobStatusDto {
            state: JobStateDto::Completed,
            error: None,
            ..status
        };
        let state = serde_json::to_value(state_notification(&terminal, 41)).expect("state");
        assert_eq!(
            state,
            json!({
                "jsonrpc": "2.0",
                "method": "job.state",
                "params": {
                    "jobId": "job-1",
                    "matchId": "match-1",
                    "state": "completed",
                    "stage": "proxy",
                    "error": null,
                    "completedStages": ["probe"],
                    "seq": 41
                }
            })
        );
    }

    #[test]
    fn facade_errors_map_to_stable_protocol_codes() {
        let rejected = map_facade_error(
            "engine.import.start",
            anyhow::anyhow!(
                "job job-2 was rejected: another resource-intensive job (job-1) is already running; \
                 only one runs at a time"
            ),
        );
        assert_eq!(rejected.code, code::JOB_REJECTED);
        assert_eq!(rejected.data()["details"]["runningJobId"], json!("job-1"));

        let toolchain = map_facade_error(
            "engine.import.start",
            anyhow::anyhow!(
                "media toolchain unavailable: ffmpeg was not found on PATH; install ffmpeg or set \
                 SPORTCUT_FFMPEG to its location"
            ),
        );
        assert_eq!(toolchain.code, code::TOOLCHAIN_UNAVAILABLE);

        let media = map_facade_error(
            "engine.import.start",
            anyhow::anyhow!("ffmpeg failed for /clip.mp4 (exit status 1): bad data"),
        );
        assert_eq!(media.code, code::MEDIA_FAILED);

        let artifact = map_facade_error(
            "engine.rally.start",
            anyhow::anyhow!(
                "player tracks are unavailable; run player tracking before rally analysis"
            ),
        );
        assert_eq!(artifact.code, code::ARTIFACT);

        let runtime = map_facade_error(
            "engine.tracking.start",
            anyhow::anyhow!(
                "player detection runtime is unavailable in this build; enable the local macOS \
                 trial runtime"
            ),
        );
        assert_eq!(runtime.code, code::UNSUPPORTED);
    }

    #[test]
    fn typed_facade_errors_map_by_variant_not_by_text() {
        // An IO failure on a manifest path must be `io`, even though the message
        // contains "manifest", which the old text matcher classified as an
        // artifact error.
        let io = anyhow::Error::new(SportcutError::io(
            "/state/matches/match-1/manifest.json",
            std::io::Error::new(std::io::ErrorKind::PermissionDenied, "denied"),
        ));
        assert_eq!(map_facade_error("engine.manifest", io).code, code::IO);

        // An unsupported feature named "player tracks" must stay `unsupported`.
        let unsupported = anyhow::Error::new(SportcutError::unsupported(
            "player tracks",
            "run tracking first",
        ));
        assert_eq!(
            map_facade_error("engine.rally.start", unsupported).code,
            code::UNSUPPORTED
        );

        // Every other variant keeps its stable code.
        let cases = [
            (
                SportcutError::InvalidInput("bad".to_string()),
                code::INVALID_PARAMS,
            ),
            (
                SportcutError::ToolchainUnavailable("missing".to_string()),
                code::TOOLCHAIN_UNAVAILABLE,
            ),
            (
                SportcutError::MediaToolFailed {
                    tool: "ffmpeg".to_string(),
                    path: "/clip.mp4".to_string(),
                    status: 1,
                    stderr: "bad".to_string(),
                },
                code::MEDIA_FAILED,
            ),
            (
                SportcutError::Probe {
                    path: "/clip.mp4".to_string(),
                    reason: "bad".to_string(),
                },
                code::PROBE_FAILED,
            ),
            (
                SportcutError::Artifact("inconsistent".to_string()),
                code::ARTIFACT,
            ),
            (
                SportcutError::JobRejected {
                    job_id: "job-2".to_string(),
                    reason: "another job (job-1) is already running".to_string(),
                },
                code::JOB_REJECTED,
            ),
            (
                SportcutError::JobFailed {
                    job_id: "job-1".to_string(),
                    stage: "proxy".to_string(),
                    reason: "bad".to_string(),
                },
                code::JOB_FAILED,
            ),
            (SportcutError::Cancelled, code::CANCELLED),
        ];
        for (error, expected) in cases {
            assert_eq!(
                map_facade_error("engine.import.start", anyhow::Error::new(error)).code,
                expected
            );
        }
    }

    #[test]
    fn caller_paths_are_confined_to_their_roots() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        std::fs::create_dir_all(state_root.join("recordings")).expect("mkdir");
        let context = ServiceContext::for_tests(&state_root);

        let outside = directory.path().join("outside.mp4");
        std::fs::write(&outside, b"x").expect("write outside");

        let error = dispatch(
            &context,
            ENGINE_PROBE,
            &json!({ "source": { "kind": "path", "value": outside.to_str().expect("utf8") } }),
        )
        .expect_err("probe outside the recording store");
        assert_eq!(error.code, code::INVALID_PARAMS, "{}", error.message);

        let error = dispatch(
            &context,
            ENGINE_IMPORT_START,
            &json!({
                "matchId": "match-1",
                "samplingRate": 2.0,
                "originalPath": outside.to_str().expect("utf8")
            }),
        )
        .expect_err("import outside the recording store");
        assert_eq!(error.code, code::INVALID_PARAMS, "{}", error.message);

        let error = dispatch(
            &context,
            ENGINE_MANIFEST,
            &json!({
                "matchId": "match-1",
                "matchDir": outside.to_str().expect("utf8")
            }),
        )
        .expect_err("matchDir outside the state root");
        assert_eq!(error.code, code::INVALID_PARAMS, "{}", error.message);
    }

    #[test]
    fn a_track_window_over_the_advertised_maximum_is_rejected() {
        let error = call(
            ENGINE_TRACKS_WINDOW,
            json!({ "matchId": "match-1", "startSeconds": 0.0, "endSeconds": 10_000.0 }),
        )
        .expect_err("window over 300s");
        assert_eq!(error.code, code::INVALID_PARAMS);
        assert!(error.message.contains("300"), "{}", error.message);
    }

    #[test]
    fn render_inputs_and_assets_are_validated_before_the_facade_runs() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        std::fs::create_dir_all(state_root.join("recordings")).expect("mkdir");
        std::fs::create_dir_all(state_root.join("render-inputs").join("uuid")).expect("mkdir");
        let context = ServiceContext::for_tests(&state_root);

        let loose = state_root.join("render-inputs").join("loose.png");
        std::fs::write(&loose, b"x").expect("write");
        let error = dispatch(
            &context,
            ENGINE_EXPORT_START,
            &json!({
                "matchId": "match-1",
                "clips": [{
                    "startSeconds": 0.0,
                    "endSeconds": 1.0,
                    "overlayPath": loose.to_str().expect("utf8")
                }],
                "leadInSeconds": 0.0,
                "leadOutSeconds": 0.0,
                "musicGain": 0.0
            }),
        )
        .expect_err("loose render input");
        assert_eq!(error.code, code::INVALID_PARAMS, "{}", error.message);

        let outside = directory.path().join("runtime.dylib");
        std::fs::write(&outside, b"x").expect("write");
        let error = dispatch(
            &context,
            ENGINE_TRACKING_START,
            &json!({
                "matchId": "match-1",
                "config": {},
                "runtimePath": outside.to_str().expect("utf8")
            }),
        )
        .expect_err("asset outside the service roots");
        assert_eq!(error.code, code::INVALID_PARAMS, "{}", error.message);
    }

    #[test]
    fn keys_round_trip_between_the_wire_and_the_dtos() {
        assert_eq!(to_camel_key("image_to_court"), "imageToCourt");
        assert_eq!(to_camel_key("job_id"), "jobId");
        assert_eq!(to_snake_key("imageToCourt"), "image_to_court");
        assert_eq!(to_snake_key("jobId"), "job_id");
        assert_eq!(
            map_keys(json!({ "outerKey": [{ "innerKey": 1 }] }), to_snake_key),
            json!({ "outer_key": [{ "inner_key": 1 }] })
        );
    }
}
