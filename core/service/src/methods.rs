//! The dispatcher seam.
//!
//! [`dispatch`] is the single entry point every request passes through. It
//! serves the lifecycle methods and routes the 17 engine methods to
//! [`crate::engine`]; catalog, metrics, diagnostics, and unknown methods remain
//! `method_not_found` until a later phase fills them in. Keeping the routing in
//! one function is what lets the transport stay ignorant of methods and the
//! handlers stay ignorant of framing and handshake state.

use serde::Serialize;
use serde_json::{json, Value};
use sportcut_api::track_artifact::TRIAL_MODEL_FINGERPRINT;
use sportcut_protocol::method::{
    required_capability, SERVICE_HEALTH, SERVICE_HELLO, SERVICE_INFO, SERVICE_PING,
    SERVICE_SHUTDOWN,
};
use sportcut_protocol::version::SERVED_CAPABILITIES;
use sportcut_protocol::{
    negotiate, CatalogInfo, HelloParams, HelloResult, ProtocolVersion, Request, RequestId,
    Response, ServiceLimits, ENGINE_METHODS, PROTOCOL_MAJOR, PROTOCOL_MINOR, PROTOCOL_VERSION,
};

use crate::engine::JobFollow;
use crate::error::ProtocolError;
use crate::idempotency::{IdempotencyStore, Lookup};
use crate::security::constant_time_eq;
use crate::server::ServiceContext;

/// Per-connection protocol state.
#[derive(Debug, Default)]
pub struct Session {
    /// Set by a successful `service.hello`; `None` rejects every other method.
    pub handshake: Option<HandshakeState>,
}

/// The negotiated state of a connection.
#[derive(Debug, Clone)]
pub struct HandshakeState {
    /// Effective protocol version selected for this connection.
    pub version: ProtocolVersion,
    /// Capability intersection the service will serve.
    pub capabilities: Vec<String>,
}

/// A request to stop the process after the current response is written.
#[derive(Debug, Clone)]
pub struct ShutdownCause {
    /// Reason reported to the client in the shutdown notification.
    pub reason: String,
    /// Whether the client asked to cancel running jobs.
    pub cancel_running_jobs: bool,
}

/// What the transport should do after a request.
#[derive(Debug)]
pub struct DispatchResult {
    /// The response to write.
    pub response: Response,
    /// Whether the connection must close after the response.
    pub close: bool,
    /// Whether the server must shut down after the response and notification.
    pub shutdown: Option<ShutdownCause>,
    /// A job this connection should follow with progress notifications.
    pub follow: Option<JobFollow>,
}

impl DispatchResult {
    fn ok(id: RequestId, result: Value) -> Self {
        Self::ok_with_follow(id, result, None)
    }

    fn ok_with_follow(id: RequestId, result: Value, follow: Option<JobFollow>) -> Self {
        Self {
            response: Response::success(id, result),
            close: false,
            shutdown: None,
            follow,
        }
    }

    fn error(id: RequestId, error: ProtocolError, close: bool) -> Self {
        Self {
            response: Response::from_error(id, error.to_object()),
            close,
            shutdown: None,
            follow: None,
        }
    }
}

/// Route one request and produce its response.
pub fn dispatch(
    context: &ServiceContext,
    session: &mut Session,
    request: &Request,
) -> DispatchResult {
    let result = route(context, session, request);
    if let Some(error) = &result.response.error {
        context.control.record_error(&error.message);
    }
    result
}

fn route(context: &ServiceContext, session: &mut Session, request: &Request) -> DispatchResult {
    let id = request.id.clone();

    if session.handshake.is_none() {
        if request.method != SERVICE_HELLO {
            return DispatchResult::error(id, ProtocolError::handshake_required(), true);
        }
        return hello(context, session, request);
    }

    if request.method == SERVICE_HELLO {
        return DispatchResult::error(
            id,
            ProtocolError::invalid_params("service.hello may only be sent once per connection"),
            false,
        );
    }

    // Protocol §2.3 and §12: a method is callable only when its capability is
    // in the negotiated intersection. Over-offering a capability does not make
    // the method appear; under-offering one makes it `method_not_found`.
    if let Some(required) = required_capability(&request.method) {
        let negotiated = session
            .handshake
            .as_ref()
            .is_some_and(|handshake| handshake.capabilities.iter().any(|value| value == required));
        if !negotiated {
            return DispatchResult::error(
                id,
                ProtocolError::method_not_found(&request.method),
                false,
            );
        }
    }

    match request.method.as_str() {
        SERVICE_HEALTH => to_result(id, health(context, session)),
        SERVICE_INFO => to_result(id, info(context)),
        SERVICE_PING => DispatchResult::ok(id, ping(context)),
        SERVICE_SHUTDOWN => shutdown(id, request),
        method if ENGINE_METHODS.contains(&method) => engine_method(context, id, request),
        // Catalog, metrics, diagnostics, and unknown methods are not served by
        // this build. A later phase replaces this arm.
        _ => DispatchResult::error(id, ProtocolError::method_not_found(&request.method), false),
    }
}

fn engine_method(context: &ServiceContext, id: RequestId, request: &Request) -> DispatchResult {
    let key = request
        .client_request_id
        .as_deref()
        .filter(|_| IdempotencyStore::is_mutating(&request.method));

    if let Some(key) = key {
        match context.idempotency.lookup(key, &request.method) {
            Lookup::Hit(result) => return DispatchResult::ok(id, result),
            Lookup::Conflict => {
                return DispatchResult::error(
                    id,
                    ProtocolError::invalid_params(
                        "clientRequestId was already used for a different method",
                    ),
                    false,
                )
            }
            Lookup::Miss => {}
        }
    }

    match crate::engine::dispatch(context, &request.method, &request.params) {
        Ok(reply) => {
            if let Some(key) = key {
                if IdempotencyStore::is_job_start(&request.method) {
                    context.idempotency.record_job_start(
                        key,
                        &request.method,
                        reply.result.clone(),
                    );
                } else {
                    context.idempotency.record_lightweight(
                        key,
                        &request.method,
                        reply.result.clone(),
                    );
                }
            }
            DispatchResult::ok_with_follow(id, reply.result, reply.follow)
        }
        Err(error) => DispatchResult::error(id, error, false),
    }
}

fn hello(context: &ServiceContext, session: &mut Session, request: &Request) -> DispatchResult {
    let id = request.id.clone();

    // Protocol §2.4: a missing token is unauthorized, not invalid params. The
    // token is checked before the rest of the payload so a client that forgot
    // it gets the stable authentication error.
    match request.params.get("token") {
        Some(Value::String(token)) if !token.is_empty() => {}
        _ => return DispatchResult::error(id, ProtocolError::unauthorized(), true),
    }

    let params: HelloParams = match serde_json::from_value(request.params.clone()) {
        Ok(params) => params,
        Err(error) => {
            return DispatchResult::error(
                id,
                ProtocolError::invalid_params(format!("service.hello params are invalid: {error}")),
                true,
            )
        }
    };

    if params.client.name.trim().is_empty()
        || params.client.version.trim().is_empty()
        || params.client.build.trim().is_empty()
    {
        return DispatchResult::error(
            id,
            ProtocolError::invalid_params(
                "service.hello client must include a non-empty name, version, and build",
            ),
            true,
        );
    }

    let version = match negotiate(PROTOCOL_VERSION, params.protocol) {
        Ok(version) => version,
        Err(mismatch) => {
            return DispatchResult::error(
                id,
                ProtocolError::new(
                    sportcut_protocol::code::VERSION_MISMATCH,
                    format!(
                        "protocol major {} is not supported; this service supports {}",
                        params.protocol.major, mismatch.supported
                    ),
                )
                .with_data_member(
                    "supported",
                    json!({
                        "major": mismatch.supported.major,
                        "minor": mismatch.supported.minor,
                    }),
                ),
                true,
            )
        }
    };

    let expected = context.current_token();
    if !constant_time_eq(params.token.as_bytes(), expected.as_bytes()) {
        return DispatchResult::error(id, ProtocolError::unauthorized(), true);
    }

    let capabilities = served_capabilities(&params.capabilities);
    context.logger.debug(
        "handshake completed",
        serde_json::Map::from_iter([
            ("client".to_string(), json!(params.client.name)),
            ("clientVersion".to_string(), json!(params.client.version)),
            ("clientBuild".to_string(), json!(params.client.build)),
            ("protocol".to_string(), json!(version)),
            ("capabilities".to_string(), json!(capabilities)),
        ]),
    );

    let result = HelloResult {
        service: context.service_info(),
        protocol: version,
        catalog: catalog_info(),
        state_root: context.state_root_string(),
        endpoint: context.endpoint_string(),
        paths: context.paths(),
        capabilities: capabilities.clone(),
        limits: ServiceLimits::default(),
    };

    session.handshake = Some(HandshakeState {
        version,
        capabilities,
    });

    to_result(id, result)
}

/// Intersect what the client offers with what this build actually serves.
fn served_capabilities(offered: &[String]) -> Vec<String> {
    SERVED_CAPABILITIES
        .iter()
        .filter(|capability| offered.iter().any(|value| value == *capability))
        .map(|capability| (*capability).to_string())
        .collect()
}

fn negotiated_version(session: &Session) -> ProtocolVersion {
    session
        .handshake
        .as_ref()
        .map_or(PROTOCOL_VERSION, |handshake| handshake.version)
}

fn catalog_info() -> CatalogInfo {
    // Phase 0-1 has no catalog. These are the Phase 3 interim values from
    // protocol §6.1: the client still owns the catalog.
    CatalogInfo {
        schema_version: 0,
        owner: "client".to_string(),
        adopted_from: None,
    }
}

fn health(context: &ServiceContext, session: &Session) -> Value {
    let running_jobs = context.control.running_jobs();
    let disk_free_bytes = disk_free(&context.state_root);
    let toolchain = toolchain_health();
    let vision = vision_health(context);

    // A missing media toolchain disables import/export; a missing inference
    // runtime disables player tracking. Neither makes the service unusable for
    // the work that does not need it, so both are `degraded`, not `not_ready`.
    let state_root_ready = context.state_root.is_dir();
    let status = if !state_root_ready || disk_free_bytes.is_none() {
        "not_ready"
    } else if !toolchain["available"].as_bool().unwrap_or(false)
        || !vision["available"].as_bool().unwrap_or(false)
    {
        "degraded"
    } else {
        "ok"
    };

    json!({
        "status": status,
        "service": context.service_info(),
        "protocol": negotiated_version(session),
        "catalog": catalog_info(),
        "stateRoot": context.state_root_string(),
        "endpoint": context.endpoint_string(),
        "uptimeMs": context.uptime_ms(),
        "pid": context.pid,
        "instanceId": context.instance_id,
        "connections": context.control.connections(),
        "runningJobs": running_jobs,
        "diskFreeBytes": disk_free_bytes,
        "toolchain": toolchain,
        "vision": vision,
        "lastError": context.control.last_error(),
        "jobs": {
            "running": context.control.running_job_ids(),
            "admission": { "heavyJobRunning": running_jobs > 0 },
        },
    })
}

fn disk_free(path: &std::path::Path) -> Option<u64> {
    let stats = nix::sys::statvfs::statvfs(path).ok()?;
    let fragment = stats.fragment_size() as u64;
    Some((stats.blocks_available() as u64).saturating_mul(fragment))
}

fn toolchain_health() -> Value {
    match sportcut_media::MediaToolchain::discover() {
        Ok(toolchain) => json!({
            "available": true,
            "ffmpeg": toolchain.ffmpeg().to_string_lossy(),
            "ffprobe": toolchain.ffprobe().to_string_lossy(),
            "version": media_version(toolchain.ffmpeg()),
        }),
        Err(error) => json!({
            "available": false,
            "detail": error.to_string(),
        }),
    }
}

/// Report the service-owned inference runtime and person model.
///
/// `available` means *runnable*: the build has `macos-tflite-eval`, both files
/// exist, and the model has the pinned trial fingerprint the player-tracking
/// job enforces. `assetsPresent` distinguishes a missing asset from a
/// present-but-unsupported one, so a build can never claim health while
/// tracking is guaranteed to fail.
fn vision_health(context: &ServiceContext) -> Value {
    let assets = &context.vision;
    let runtime = assets.runtime.as_deref();
    let model = assets.model.as_deref();

    let built_in = cfg!(all(target_os = "macos", feature = "macos-tflite-eval"));
    let runtime_file = runtime.filter(|path| path.is_file());
    let model_file = model.filter(|path| path.is_file());
    let assets_present = runtime_file.is_some() && model_file.is_some();
    let model_supported = model_file.is_some()
        && assets.model_fingerprint.as_deref() == Some(TRIAL_MODEL_FINGERPRINT);
    let available = built_in && runtime_file.is_some() && model_supported;

    let detail = if !built_in {
        Some(
            "this build lacks the macos-tflite-eval feature; rebuild sportcut-service with \
             --features macos-tflite-eval"
                .to_string(),
        )
    } else {
        missing_vision_asset(runtime, runtime_file, "TFLite runtime")
            .or_else(|| missing_vision_asset(model, model_file, "person model"))
            .or_else(|| {
                (!model_supported).then(|| match assets.model_fingerprint.as_deref() {
                    Some(fingerprint) => format!(
                        "person model at {} is not the supported EfficientDet-Lite0 trial file \
                         (fingerprint {fingerprint}); run tools/fetch-inference-assets.sh",
                        model.map_or_else(
                            || "<unknown>".to_string(),
                            |path| path.display().to_string()
                        )
                    ),
                    None => format!(
                        "person model at {} could not be read; run tools/fetch-inference-assets.sh",
                        model.map_or_else(
                            || "<unknown>".to_string(),
                            |path| path.display().to_string()
                        )
                    ),
                })
            })
    };

    json!({
        "available": available,
        "assetsPresent": assets_present,
        "runtimePath": runtime.map(|path| path.to_string_lossy().into_owned()),
        "modelPath": model.map(|path| path.to_string_lossy().into_owned()),
        "modelFingerprint": assets.model_fingerprint,
        "detail": detail,
    })
}

/// Describe a missing inference asset. A path that is set but absent is more
/// actionable than a path that was never configured.
fn missing_vision_asset(
    configured: Option<&std::path::Path>,
    file: Option<&std::path::Path>,
    description: &str,
) -> Option<String> {
    if file.is_some() {
        return None;
    }
    Some(match configured {
        Some(path) => format!("{description} is missing at {}", path.display()),
        None => format!("{description} is not configured"),
    })
}

fn media_version(ffmpeg: &std::path::Path) -> Option<String> {
    let output = std::process::Command::new(ffmpeg)
        .arg("-version")
        .output()
        .ok()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    stdout
        .lines()
        .next()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_string)
}

fn info(context: &ServiceContext) -> Value {
    json!({
        "service": context.service_info(),
        "protocolRange": {
            "major": PROTOCOL_MAJOR,
            "minMinor": 0,
            "maxMinor": PROTOCOL_MINOR,
        },
        "stateRoot": context.state_root_string(),
        "endpoint": context.endpoint_string(),
        "paths": context.paths(),
        "limits": ServiceLimits::default(),
    })
}

fn ping(context: &ServiceContext) -> Value {
    json!({ "pong": true, "uptimeMs": context.uptime_ms() })
}

fn shutdown(id: RequestId, request: &Request) -> DispatchResult {
    let cancel_running_jobs = match request.params.get("cancelRunningJobs") {
        None => true,
        Some(Value::Bool(value)) => *value,
        Some(_) => {
            return DispatchResult::error(
                id,
                ProtocolError::invalid_params("cancelRunningJobs must be a boolean"),
                false,
            )
        }
    };

    let reason = match request.params.get("reason") {
        None => "client requested shutdown".to_string(),
        Some(Value::String(value)) => value.clone(),
        Some(_) => {
            return DispatchResult::error(
                id,
                ProtocolError::invalid_params("reason must be a string"),
                false,
            )
        }
    };

    let mut result = DispatchResult::ok(id, json!({ "accepted": true }));
    result.shutdown = Some(ShutdownCause {
        reason,
        cancel_running_jobs,
    });
    result
}

fn to_result<T: Serialize>(id: RequestId, value: T) -> DispatchResult {
    match serde_json::to_value(value) {
        Ok(value) => DispatchResult::ok(id, value),
        Err(error) => DispatchResult::error(
            id,
            ProtocolError::new(
                sportcut_protocol::code::INTERNAL,
                format!("failed to serialize the result: {error}"),
            ),
            false,
        ),
    }
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use serde_json::json;
    use sportcut_protocol::version::capability;
    use sportcut_protocol::ClientInfo;

    use super::*;

    fn context(token: &str) -> ServiceContext {
        let mut context = ServiceContext::for_tests(Path::new("/state"));
        context.token = token.to_string();
        context
    }

    fn hello_request(token: &str, capabilities: Vec<&str>) -> Request {
        let params = HelloParams::new(
            PROTOCOL_VERSION,
            ClientInfo {
                name: "Sportcut.app".to_string(),
                version: "0.1.0".to_string(),
                build: "build-1".to_string(),
            },
            token,
            capabilities.into_iter().map(str::to_string).collect(),
        );
        Request::new(
            1_i64,
            SERVICE_HELLO,
            serde_json::to_value(params).expect("params"),
        )
    }

    fn request(method: &str) -> Request {
        Request::new(2_i64, method, json!({}))
    }

    #[test]
    fn a_method_before_hello_requires_the_handshake() {
        let context = context("token");
        let mut session = Session::default();
        let result = dispatch(&context, &mut session, &request(SERVICE_PING));

        assert!(result.close);
        assert_eq!(
            result.response.error.expect("error").code,
            sportcut_protocol::code::HANDSHAKE_REQUIRED
        );
    }

    #[test]
    fn a_valid_hello_negotiates_capabilities_and_unlocks_methods() {
        let context = context("token");
        let mut session = Session::default();
        let result = dispatch(
            &context,
            &mut session,
            &hello_request(
                "token",
                vec![capability::ENGINE_V1, capability::METRICS_V1, "unknown.v9"],
            ),
        );

        assert!(!result.close);
        let response = result.response.result.expect("result");
        assert_eq!(response["service"]["name"], "sportcutd");
        assert_eq!(response["protocol"], json!({ "major": 1, "minor": 0 }));
        assert_eq!(
            response["capabilities"],
            json!([capability::ENGINE_V1]),
            "only served capabilities are returned, even when the client over-offers"
        );
        assert_eq!(response["limits"]["maxFrameBytes"], 16_777_216);
        assert_eq!(response["paths"]["recordings"], "/state/recordings");
        assert!(session.handshake.is_some());

        let ping = dispatch(&context, &mut session, &request(SERVICE_PING));
        assert_eq!(ping.response.result.expect("ping")["pong"], true);
    }

    #[test]
    fn a_wrong_token_is_unauthorized_and_closes() {
        let context = context("token");
        let mut session = Session::default();
        let result = dispatch(
            &context,
            &mut session,
            &hello_request("wrong", vec![capability::ENGINE_V1]),
        );

        assert!(result.close);
        assert!(session.handshake.is_none());
        let error = result.response.error.expect("error");
        assert_eq!(error.code, sportcut_protocol::code::UNAUTHORIZED);
        assert_eq!(
            error.data.expect("data")["kind"],
            json!(sportcut_protocol::kind::UNAUTHORIZED)
        );
    }

    #[test]
    fn a_major_version_mismatch_reports_the_supported_version_and_closes() {
        let context = context("token");
        let mut session = Session::default();
        let params = HelloParams::new(
            ProtocolVersion::new(2, 3),
            ClientInfo {
                name: "Sportcut.app".to_string(),
                version: "0.1.0".to_string(),
                build: "build-1".to_string(),
            },
            "token",
            Vec::new(),
        );
        let request = Request::new(
            1_i64,
            SERVICE_HELLO,
            serde_json::to_value(params).expect("params"),
        );

        let result = dispatch(&context, &mut session, &request);
        assert!(result.close);
        let error = result.response.error.expect("error");
        assert_eq!(error.code, sportcut_protocol::code::VERSION_MISMATCH);
        let data = error.data.expect("data");
        assert_eq!(data["supported"], json!({ "major": 1, "minor": 0 }));
    }

    #[test]
    fn a_second_hello_is_invalid_input_but_keeps_the_connection() {
        let context = context("token");
        let mut session = Session::default();
        dispatch(&context, &mut session, &hello_request("token", Vec::new()));

        let result = dispatch(&context, &mut session, &hello_request("token", Vec::new()));
        assert!(!result.close);
        assert_eq!(
            result.response.error.expect("error").code,
            sportcut_protocol::code::INVALID_PARAMS
        );
    }

    #[test]
    fn unknown_methods_are_not_found() {
        let context = context("token");
        let mut session = Session::default();
        dispatch(&context, &mut session, &hello_request("token", Vec::new()));

        for method in ["engine.start.doesNotExist", "catalog.match.get"] {
            let result = dispatch(&context, &mut session, &request(method));
            assert!(!result.close, "{method} does not close the connection");
            assert_eq!(
                result.response.error.expect("error").code,
                sportcut_protocol::code::METHOD_NOT_FOUND,
                "{method}"
            );
        }
    }

    #[test]
    fn engine_methods_require_the_negotiated_capability() {
        let context = context("token");

        // Under-offering `engine.v1` makes every engine method not found.
        let mut without_engine = Session::default();
        dispatch(
            &context,
            &mut without_engine,
            &hello_request("token", vec![capability::NOTIFICATIONS_V1]),
        );
        let denied = dispatch(
            &context,
            &mut without_engine,
            &request(sportcut_protocol::method::ENGINE_IMPORT_STAGES),
        );
        assert_eq!(
            denied.response.error.expect("error").code,
            sportcut_protocol::code::METHOD_NOT_FOUND
        );

        // Offering it unlocks the same method.
        let mut with_engine = Session::default();
        dispatch(
            &context,
            &mut with_engine,
            &hello_request("token", vec![capability::ENGINE_V1]),
        );
        let allowed = dispatch(
            &context,
            &mut with_engine,
            &request(sportcut_protocol::method::ENGINE_IMPORT_STAGES),
        );
        assert!(allowed.response.error.is_none());
        assert_eq!(
            allowed.response.result.expect("stages")["stages"][0],
            "probe"
        );
    }

    #[test]
    fn a_missing_token_is_unauthorized_even_before_the_payload_is_read() {
        let context = context("token");
        let mut session = Session::default();
        let mut request = hello_request("token", vec![capability::ENGINE_V1]);
        request
            .params
            .as_object_mut()
            .expect("params")
            .remove("token");

        let result = dispatch(&context, &mut session, &request);
        assert!(result.close);
        assert_eq!(
            result.response.error.expect("error").code,
            sportcut_protocol::code::UNAUTHORIZED
        );
        assert!(session.handshake.is_none());
    }

    #[test]
    fn the_token_file_is_read_at_each_handshake_for_a_relaunch() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path();
        std::fs::create_dir_all(state_root.join("run")).expect("run");
        let token_file = state_root.join("run").join("token");
        std::fs::write(&token_file, "token-from-first-launch").expect("write token");

        let mut context = ServiceContext::for_tests(state_root);
        context.token = "token-from-first-launch".to_string();
        context.token_file = token_file.clone();

        // The app relaunches while the service is alive and rewrites the token.
        std::fs::write(&token_file, "token-from-second-launch").expect("rewrite token");

        let mut session = Session::default();
        let result = dispatch(
            &context,
            &mut session,
            &hello_request("token-from-second-launch", vec![capability::ENGINE_V1]),
        );
        assert!(result.response.error.is_none(), "the new token is accepted");
        assert!(session.handshake.is_some());
    }

    #[test]
    fn a_repeated_client_request_id_returns_the_stored_result() {
        let context = context("token");
        context.idempotency.record_job_start(
            "key-1",
            "engine.import.start",
            json!({ "jobId": "job-existing", "matchId": "match-1" }),
        );
        let mut session = Session::default();
        dispatch(
            &context,
            &mut session,
            &hello_request("token", vec![capability::ENGINE_V1]),
        );

        let mut request = Request::new(
            5_i64,
            "engine.import.start",
            json!({ "matchId": "match-1", "samplingRate": 2.0 }),
        );
        request.client_request_id = Some("key-1".to_string());
        let result = dispatch(&context, &mut session, &request);

        assert_eq!(
            result.response.result.expect("cached result")["jobId"],
            "job-existing"
        );
        assert_eq!(context.control.running_jobs(), 0, "no new job was admitted");
    }

    #[test]
    fn reusing_a_key_for_another_method_is_invalid() {
        let context = context("token");
        context.idempotency.record_job_start(
            "key-1",
            "engine.import.start",
            json!({ "jobId": "job-existing" }),
        );
        let mut session = Session::default();
        dispatch(
            &context,
            &mut session,
            &hello_request("token", vec![capability::ENGINE_V1]),
        );

        let mut request = Request::new(
            6_i64,
            "engine.export.start",
            json!({
                "matchId": "match-1",
                "clips": [{ "startSeconds": 0.0, "endSeconds": 1.0 }],
                "leadInSeconds": 0.0,
                "leadOutSeconds": 0.0,
                "musicGain": 0.0
            }),
        );
        request.client_request_id = Some("key-1".to_string());
        let result = dispatch(&context, &mut session, &request);
        assert_eq!(
            result.response.error.expect("error").code,
            sportcut_protocol::code::INVALID_PARAMS
        );
    }

    #[test]
    fn health_reports_readiness_inputs() {
        let directory = tempfile::tempdir().expect("temp dir");
        let context = ServiceContext::for_tests(directory.path());
        let mut session = Session::default();
        dispatch(
            &context,
            &mut session,
            &hello_request("token", vec![capability::ENGINE_V1]),
        );

        let result = dispatch(&context, &mut session, &request(SERVICE_HEALTH));
        let health = result.response.result.expect("health");
        assert!(
            ["ok", "degraded", "not_ready"].contains(&health["status"].as_str().unwrap()),
            "{health}"
        );
        assert!(health["diskFreeBytes"].as_u64().is_some() || health["diskFreeBytes"].is_null());
        assert!(health["toolchain"]["available"].is_boolean());
        assert!(health["vision"]["available"].is_boolean());
        assert!(health["vision"]["assetsPresent"].is_boolean());
        assert!(health["vision"].get("runtimePath").is_some());
        assert!(health["vision"].get("modelPath").is_some());
        assert!(health["vision"].get("modelFingerprint").is_some());
        assert!(health["vision"].get("detail").is_some());
        assert!(health.get("lastError").is_some());
        assert_eq!(health["jobs"]["admission"]["heavyJobRunning"], false);

        context.control.record_error("a previous failure");
        let result = dispatch(&context, &mut session, &request(SERVICE_HEALTH));
        assert_eq!(
            result.response.result.expect("health")["lastError"],
            "a previous failure"
        );
    }

    #[test]
    fn a_pure_engine_method_is_routed_after_the_handshake() {
        let context = context("token");
        let mut session = Session::default();
        dispatch(
            &context,
            &mut session,
            &hello_request("token", vec![capability::ENGINE_V1]),
        );

        let result = dispatch(
            &context,
            &mut session,
            &Request::new(
                7_i64,
                sportcut_protocol::method::ENGINE_SERVING_SIDES,
                serde_json::json!({
                    "rallies": [{ "rallyId": "rally-1", "winner": "left" }]
                }),
            ),
        );

        assert!(!result.close);
        assert!(result.follow.is_none());
        assert_eq!(
            result.response.result.expect("result"),
            serde_json::json!({
                "rallies": [{ "rallyId": "rally-1", "side": null }]
            })
        );
    }

    #[test]
    fn shutdown_is_accepted_and_requests_process_exit() {
        let context = context("token");
        let mut session = Session::default();
        dispatch(&context, &mut session, &hello_request("token", Vec::new()));

        let mut request = Request::new(3_i64, SERVICE_SHUTDOWN, json!({ "reason": "app quit" }));
        request.params["cancelRunningJobs"] = json!(true);
        let result = dispatch(&context, &mut session, &request);

        assert_eq!(result.response.result.expect("result")["accepted"], true);
        let cause = result.shutdown.expect("shutdown cause");
        assert_eq!(cause.reason, "app quit");
        assert!(cause.cancel_running_jobs);
    }
}
