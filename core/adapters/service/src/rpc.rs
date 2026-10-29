//! Per-connection framing, request classification, and response writing.
//!
//! One thread serves one connection. The thread reads length-prefixed JSON
//! frames with [`sportcut_protocol::read_frame`], classifies each payload as a
//! request, a notification, or a malformed message, and hands requests to the
//! dispatcher seam in [`crate::methods`]. It owns the handshake gate: before a
//! successful `service.hello`, every other request is rejected and the
//! connection is closed.

use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use serde::Serialize;
use serde_json::{json, Value};
use sportcut_protocol::{
    code, read_frame, write_frame, FrameError, JsonRpcVersion, Notification, Request, RequestId,
};

use crate::engine::{self, JobFollow};
use crate::error::ProtocolError;
use crate::methods::{self, Session};
use crate::server::{Control, ServiceContext, CONNECTION_IDLE_TIMEOUT, HANDSHAKE_TIMEOUT};

/// How long the client is told it has to finish a shutdown.
const SHUTDOWN_DEADLINE_MS: u32 = 10_000;

/// Default params limit for a lightweight method, protocol §7.
const PARAMS_MAX_BYTES: usize = 1024 * 1024;

/// Params limit for the two bulk editing methods, protocol §7.
const LARGE_PARAMS_MAX_BYTES: usize = 8 * 1024 * 1024;

/// Methods allowed the larger params budget.
const LARGE_PARAMS_METHODS: [&str; 2] = ["library.score.replace", "library.clip.reorder"];

/// Serve one accepted connection until the client closes it or a rule fires.
pub fn serve_connection(mut stream: UnixStream, context: Arc<ServiceContext>) {
    let _ = stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT));
    let writer = match stream.try_clone() {
        Ok(clone) => Arc::new(Mutex::new(clone)),
        Err(error) => {
            context
                .logger
                .warn(format!("failed to split the connection: {error}"));
            return;
        }
    };
    let connection_open = Arc::new(AtomicBool::new(true));
    let mut session = Session::default();
    let mut idle_timeout_set = false;

    loop {
        if context.control.shutdown_requested() {
            break;
        }

        let value = match read_frame(&mut stream) {
            Ok(value) => value,
            Err(FrameError::Empty) => {
                write_error(
                    &writer,
                    None,
                    &ProtocolError::new(
                        sportcut_protocol::code::FRAME_TOO_LARGE,
                        "frame payload must not be zero length",
                    ),
                );
                break;
            }
            Err(FrameError::TooLarge { length }) => {
                write_error(
                    &writer,
                    None,
                    &ProtocolError::new(
                        sportcut_protocol::code::FRAME_TOO_LARGE,
                        format!("frame payload length {length} exceeds the 16 MiB limit"),
                    ),
                );
                break;
            }
            Err(FrameError::InvalidUtf8(error)) => {
                write_parse_error(
                    &writer,
                    format!("frame payload is not valid UTF-8: {error}"),
                );
                break;
            }
            Err(FrameError::InvalidJson(error)) => {
                write_parse_error(&writer, format!("frame payload is not valid JSON: {error}"));
                break;
            }
            Err(FrameError::NotAnObject) => {
                // Protocol §1.4 and §8: a batch/array (or any non-object) is
                // `invalid_request`, not `parse_error`.
                write_error(
                    &writer,
                    None,
                    &ProtocolError::invalid_request(
                        "frame payload must be a JSON object; batches are not supported",
                    ),
                );
                break;
            }
            // `read_frame` never serializes; the arm keeps the match exhaustive.
            Err(FrameError::Serialize(_)) | Err(FrameError::Io(_)) => break,
        };

        match classify(&value) {
            Classified::Notification => continue,
            Classified::Invalid { id, error } => {
                write_error(&writer, id.as_ref(), &error);
            }
            Classified::Request(request) => {
                let result = methods::dispatch(&context, &mut session, &request);

                // Register before writing the response: the facade has already
                // admitted the job, so a failed write must not lose the slot.
                if let Some(follow) = result.follow.as_ref() {
                    context
                        .control
                        .job_started(follow.job_id.clone(), follow.match_id.clone());
                }

                if !respond(&writer, &result.response) {
                    // No monitor will be spawned, so do not leak the slot.
                    if let Some(follow) = result.follow.as_ref() {
                        context.control.job_finished(&follow.job_id);
                    }
                    break;
                }

                if let Some(cause) = result.shutdown {
                    let notification = Notification::new(
                        sportcut_protocol::method::SERVICE_SHUTDOWN,
                        json!({
                            "reason": cause.reason,
                            "deadlineMs": SHUTDOWN_DEADLINE_MS,
                        }),
                    );
                    let _ = write_shared(&writer, &notification);
                    if cause.cancel_running_jobs {
                        context.control.request_shutdown_cancelling(cause.reason);
                    } else {
                        context.control.request_shutdown(cause.reason);
                    }
                    break;
                }

                if result.close {
                    break;
                }

                if let Some(follow) = result.follow {
                    spawn_follow(
                        follow,
                        Arc::clone(&writer),
                        Arc::clone(&connection_open),
                        Arc::clone(&context.control),
                        context.logger.clone(),
                    );
                }

                if !idle_timeout_set && session.handshake.is_some() {
                    let _ = stream.set_read_timeout(Some(CONNECTION_IDLE_TIMEOUT));
                    idle_timeout_set = true;
                }
            }
        }
    }

    connection_open.store(false, Ordering::SeqCst);
    let _ = stream.shutdown(Shutdown::Both);
}

/// Write a response, translating an oversized result into `response_too_large`.
///
/// Returns `false` when the connection must close. Protocol §7: a result larger
/// than 16 MiB is an error the client can act on, not a silent EOF.
fn respond(writer: &Mutex<UnixStream>, response: &sportcut_protocol::Response) -> bool {
    match write_shared(writer, response) {
        Ok(()) => true,
        Err(FrameError::TooLarge { .. }) => {
            let error = ProtocolError::new(
                code::RESPONSE_TOO_LARGE,
                "the result exceeds the 16 MiB response limit; narrow the request",
            );
            write_error(writer, Some(&response.id), &error);
            false
        }
        Err(_) => false,
    }
}

/// Spawn a thread that follows one job and writes its notifications.
fn spawn_follow(
    follow: JobFollow,
    writer: Arc<Mutex<UnixStream>>,
    connection_open: Arc<AtomicBool>,
    control: Arc<Control>,
    logger: crate::logging::Logger,
) {
    let job_id = follow.job_id.clone();
    let registered_id = job_id.clone();
    let thread_control = Arc::clone(&control);
    let thread_logger = logger.clone();
    let spawned = thread::Builder::new()
        .name(format!("sportcut-follow-{job_id}"))
        .spawn(move || {
            follow_job(
                &follow,
                &writer,
                &connection_open,
                &thread_control,
                &thread_logger,
            )
        });

    if let Err(error) = spawned {
        // No monitor is running, so do not leak the lifecycle slot.
        control.job_finished(&registered_id);
        logger.warn(format!("failed to follow job {registered_id}: {error}"));
    }
}

/// What the client last saw, so an unchanged status is not re-sent.
#[derive(PartialEq)]
struct ProgressKey {
    state: sportcut_api::JobStateDto,
    stage: Option<String>,
    value_bits: u64,
    message: Option<String>,
    completed_stages: Vec<String>,
}

impl ProgressKey {
    fn of(status: &sportcut_api::JobStatusDto) -> Self {
        let progress = status.progress.as_ref();
        Self {
            state: status.state,
            stage: status.stage.clone(),
            value_bits: progress.map_or(0, |progress| progress.value.to_bits()),
            message: progress.and_then(|progress| progress.message.clone()),
            completed_stages: status.completed_stages.clone(),
        }
    }
}

/// Poll the facade's registry at the coalescing ceiling and write
/// `job.progress`, then one terminal `job.state`.
///
/// The thread stops when the job reaches a terminal state, when the connection
/// closes (a write fails or the connection flag clears), or when the service
/// begins shutting down. It shares the connection's writer lock, so a
/// notification frame is never interleaved with a response.
fn follow_job(
    follow: &JobFollow,
    writer: &Mutex<UnixStream>,
    connection_open: &AtomicBool,
    control: &Control,
    logger: &crate::logging::Logger,
) {
    let mut seq = 0_u64;
    let mut last: Option<ProgressKey> = None;

    // The monitor outlives the connection: a client may disconnect while a job
    // still runs, and the lifecycle must keep counting it until it is terminal.
    // Notifications are skipped once the connection is gone.
    loop {
        let status = match sportcut_api::job_status(follow.job_id.clone()) {
            Ok(status) => status,
            Err(error) => {
                // The job is no longer retained, so it is terminal or was lost;
                // either way it no longer blocks exit.
                logger.debug(
                    "job is no longer retained",
                    serde_json::Map::from_iter([
                        ("jobId".to_string(), json!(follow.job_id)),
                        ("error".to_string(), json!(error.to_string())),
                    ]),
                );
                control.job_finished(&follow.job_id);
                return;
            }
        };

        let connected = connection_open.load(Ordering::SeqCst);

        if engine::is_terminal(status.state) {
            if connected {
                seq += 1;
                let _ = write_shared(writer, &engine::state_notification(&status, seq));
            }
            control.job_finished(&follow.job_id);
            return;
        }

        if connected && status.progress.is_some() {
            let key = ProgressKey::of(&status);
            if last.as_ref() != Some(&key) {
                last = Some(key);
                seq += 1;
                if write_shared(writer, &engine::progress_notification(&status, seq)).is_err() {
                    // The connection closed; keep watching the job.
                }
            }
        }

        // Poll more slowly with no client to notify.
        thread::sleep(if connected {
            engine::PROGRESS_INTERVAL
        } else {
            Duration::from_millis(250)
        });
    }
}

/// Serialize under the connection's writer lock so frames never interleave.
fn write_shared<T: Serialize + ?Sized>(
    writer: &Mutex<UnixStream>,
    message: &T,
) -> Result<(), FrameError> {
    let mut stream = writer
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    write_frame(&mut *stream, message)
}

/// The three shapes a frame payload can have.
#[derive(Debug)]
enum Classified {
    /// A request with an id, to be dispatched.
    Request(Request),
    /// A message without an `id` member at all; ignored, as JSON-RPC allows.
    Notification,
    /// A malformed request. `id` is `None` when the id itself was unusable, in
    /// which case the response still uses `null` as the id.
    Invalid {
        id: Option<RequestId>,
        error: ProtocolError,
    },
}

fn classify(value: &Value) -> Classified {
    let id_member = value.get("id");
    let id_present = id_member.is_some();
    let id = extract_id(value);

    // Protocol §1.4: a request id must be a string or an integer and must not
    // be null. A present-but-unusable id is `invalid_request`, not a
    // notification, so the client is told its request was rejected.
    if id_present && id.is_none() {
        return Classified::Invalid {
            id: None,
            error: ProtocolError::invalid_request(
                "request id must be a string or an integer and must not be null",
            ),
        };
    }

    let Some(method) = value.get("method").and_then(Value::as_str) else {
        return invalid(id_present, id, "request method must be a string");
    };

    if value.get("jsonrpc").and_then(Value::as_str) != Some(JsonRpcVersion::VERSION) {
        return invalid(id_present, id, "request jsonrpc must be the string \"2.0\"");
    }

    let params = match value.get("params") {
        None => json!({}),
        Some(Value::Object(_)) => value["params"].clone(),
        Some(_) => return invalid(id_present, id, "request params must be a JSON object"),
    };

    // Protocol §7: params are at most 1 MiB, or 8 MiB for the two bulk
    // editing methods.
    let limit = if LARGE_PARAMS_METHODS.contains(&method) {
        LARGE_PARAMS_MAX_BYTES
    } else {
        PARAMS_MAX_BYTES
    };
    let size = serde_json::to_vec(&params)
        .map(|bytes| bytes.len())
        .unwrap_or(0);
    if size > limit {
        let error = ProtocolError::invalid_params(format!(
            "params are {size} bytes; the limit for {method} is {limit} bytes"
        ));
        return if id_present {
            Classified::Invalid { id, error }
        } else {
            Classified::Notification
        };
    }

    let Some(id) = id else {
        return Classified::Notification;
    };

    Classified::Request(Request {
        jsonrpc: JsonRpcVersion,
        id,
        method: method.to_string(),
        params,
        client_request_id: value
            .get("clientRequestId")
            .and_then(Value::as_str)
            .map(str::to_string),
    })
}

/// Build an `Invalid` result, or ignore a malformed message that has no `id`
/// member at all.
fn invalid(id_present: bool, id: Option<RequestId>, message: impl Into<String>) -> Classified {
    if id_present {
        Classified::Invalid {
            id,
            error: ProtocolError::invalid_request(message),
        }
    } else {
        Classified::Notification
    }
}

fn extract_id(value: &Value) -> Option<RequestId> {
    match value.get("id")? {
        Value::String(text) => Some(RequestId::String(text.clone())),
        Value::Number(number) => number.as_i64().map(RequestId::Number),
        _ => None,
    }
}

fn write_parse_error(writer: &Mutex<UnixStream>, message: impl Into<String>) {
    let error = ProtocolError::new(sportcut_protocol::code::PARSE_ERROR, message.into());
    write_error(writer, None, &error);
}

fn write_error(writer: &Mutex<UnixStream>, id: Option<&RequestId>, error: &ProtocolError) {
    let id_value = match id {
        Some(id) => serde_json::to_value(id).unwrap_or(Value::Null),
        None => Value::Null,
    };
    let message = json!({
        "jsonrpc": JsonRpcVersion::VERSION,
        "id": id_value,
        "error": error.to_object(),
    });
    let _ = write_shared(writer, &message);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_complete_request_is_classified() {
        let value = json!({
            "jsonrpc": "2.0",
            "id": 7,
            "method": "service.ping",
            "params": {},
            "clientRequestId": "key-1",
        });

        match classify(&value) {
            Classified::Request(request) => {
                assert_eq!(request.id, RequestId::Number(7));
                assert_eq!(request.method, "service.ping");
                assert_eq!(request.params, json!({}));
                assert_eq!(request.client_request_id.as_deref(), Some("key-1"));
            }
            other => panic!("expected a request, got {other:?}"),
        }
    }

    #[test]
    fn a_message_without_an_id_is_a_notification() {
        let value = json!({ "jsonrpc": "2.0", "method": "job.progress", "params": {} });
        assert!(matches!(classify(&value), Classified::Notification));
    }

    #[test]
    fn malformed_requests_with_an_id_are_invalid_requests() {
        for value in [
            json!({ "jsonrpc": "1.0", "id": 1, "method": "service.ping", "params": {} }),
            json!({ "jsonrpc": "2.0", "id": 1, "method": 42, "params": {} }),
            json!({ "jsonrpc": "2.0", "id": 1, "method": "service.ping", "params": [] }),
        ] {
            match classify(&value) {
                Classified::Invalid { id, error } => {
                    assert_eq!(id, Some(RequestId::Number(1)));
                    assert_eq!(error.code, sportcut_protocol::code::INVALID_REQUEST);
                }
                other => panic!("expected an invalid request, got {other:?}"),
            }
        }
    }

    #[test]
    fn missing_params_defaults_to_an_empty_object() {
        let value = json!({ "jsonrpc": "2.0", "id": "a", "method": "service.ping" });
        match classify(&value) {
            Classified::Request(request) => assert_eq!(request.params, json!({})),
            other => panic!("expected a request, got {other:?}"),
        }
    }

    #[test]
    fn string_ids_are_preserved() {
        let value =
            json!({ "jsonrpc": "2.0", "id": "request-a", "method": "service.ping", "params": {} });
        match classify(&value) {
            Classified::Request(request) => {
                assert_eq!(request.id, RequestId::String("request-a".to_string()))
            }
            other => panic!("expected a request, got {other:?}"),
        }
    }

    #[test]
    fn null_and_float_ids_are_invalid_requests() {
        for value in [
            json!({ "jsonrpc": "2.0", "id": null, "method": "service.ping", "params": {} }),
            json!({ "jsonrpc": "2.0", "id": 1.5, "method": "service.ping", "params": {} }),
        ] {
            match classify(&value) {
                Classified::Invalid { id, error } => {
                    assert_eq!(id, None, "an unusable id is reported as null");
                    assert_eq!(error.code, sportcut_protocol::code::INVALID_REQUEST);
                }
                other => panic!("expected an invalid request, got {other:?}"),
            }
        }
    }

    #[test]
    fn a_request_without_an_id_member_is_still_a_notification() {
        let value = json!({ "jsonrpc": "2.0", "method": "service.shutdown", "params": {} });
        assert!(matches!(classify(&value), Classified::Notification));
    }

    #[test]
    fn oversized_params_are_rejected_and_bulk_methods_have_a_larger_budget() {
        let huge = "x".repeat(PARAMS_MAX_BYTES + 1);
        let over = json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "engine.servingSides",
            "params": { "rallies": huge },
        });
        match classify(&over) {
            Classified::Invalid { id, error } => {
                assert_eq!(id, Some(RequestId::Number(1)));
                assert_eq!(error.code, sportcut_protocol::code::INVALID_PARAMS);
            }
            other => panic!("expected invalid params, got {other:?}"),
        }

        let bulk_payload = "x".repeat(PARAMS_MAX_BYTES + 1024);
        let bulk = json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "library.score.replace",
            "params": { "events": bulk_payload },
        });
        assert!(matches!(classify(&bulk), Classified::Request(_)));
    }

    #[test]
    fn an_oversized_response_returns_response_too_large_instead_of_eof() {
        let (server, client) = UnixStream::pair().expect("socket pair");
        client
            .set_read_timeout(Some(Duration::from_secs(5)))
            .expect("timeout");
        let writer = Mutex::new(server);

        let response = sportcut_protocol::Response::success(
            7_i64,
            json!("x".repeat(sportcut_protocol::MAX_FRAME_BYTES)),
        );
        assert!(!respond(&writer, &response), "the connection closes");

        let mut client = client;
        let error = read_frame(&mut client).expect("an error frame is written");
        assert_eq!(error["id"], 7);
        assert_eq!(
            error["error"]["code"],
            sportcut_protocol::code::RESPONSE_TOO_LARGE
        );
        assert_eq!(
            error["error"]["data"]["kind"],
            sportcut_protocol::kind::RESPONSE_TOO_LARGE
        );
    }
}
