//! Listener, connection registry, and the process lifecycle state machine.
//!
//! The lifecycle rules are background-service §4.9: a running job blocks exit,
//! `service.shutdown` wins over every timer, a missing parent starts a grace
//! timer (or cancels a running job), and the process exits after the configured
//! idle threshold with no connections and no jobs. The running-job set is
//! authoritative: the transport registers a job when the facade admits it and
//! clears it when the transport observes a terminal state, so idle exit,
//! parent-gone, health, and shutdown all see live work.

use std::collections::HashMap;
use std::fmt;
use std::fs;
use std::io;
use std::net::Shutdown;
use std::os::unix::fs::FileTypeExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Component, Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{bail, Context, Result};
use sportcut_protocol::{ServiceInfo, ServicePaths};

use crate::config::Config;
use crate::idempotency::IdempotencyStore;
use crate::logging::Logger;
use crate::os_glue::{self, InstanceLock};
use crate::rpc;
use crate::security::{self, PRIVATE_FILE_MODE};
use crate::state_root::Layout;

/// How long a connection has to complete `service.hello`.
pub const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);

/// How long a connection may go without a frame before it is closed.
pub const CONNECTION_IDLE_TIMEOUT: Duration = Duration::from_secs(300);

/// Executable name reported in the handshake.
pub const SERVICE_NAME: &str = "sportcutd";

/// Environment variable the app may use to hand the token to the service.
pub const TOKEN_ENV: &str = "SPORTCUT_SERVICE_TOKEN";

/// Open connections this build accepts; must match the advertised limit.
pub const MAX_CONNECTIONS: usize = 8;

/// How long `service.shutdown` waits for cooperative job cancellation.
pub const SHUTDOWN_WAIT: Duration = Duration::from_secs(10);

const ACCEPT_POLL_INTERVAL: Duration = Duration::from_millis(25);
const SHUTDOWN_FLUSH_GRACE: Duration = Duration::from_millis(100);

/// The build identifier reported in the handshake.
pub fn service_build() -> &'static str {
    option_env!("SPORTCUT_SERVICE_BUILD").unwrap_or("phase0-1")
}

/// The result of binding the listener.
#[derive(Debug)]
pub enum BindResult {
    /// This process owns the endpoint and should run.
    Started(Server),
    /// Another process holds the single-instance lock.
    AlreadyRunning {
        /// Endpoint the existing instance owns.
        endpoint: PathBuf,
    },
}

/// A bound, not-yet-running service.
#[derive(Debug)]
pub struct Server {
    config: Config,
    endpoint: PathBuf,
    token_file: PathBuf,
    endpoint_file: PathBuf,
    listener: UnixListener,
    control: Arc<Control>,
    registry: ConnectionRegistry,
    context: Arc<ServiceContext>,
    lock: Option<InstanceLock>,
    next_connection_id: AtomicU64,
}

impl Server {
    /// Validate the configuration, take the lock, write the token, and bind.
    ///
    /// Endpoint length and location are checked before any socket is created,
    /// and a stale socket is removed only after the instance lock proves no
    /// live owner.
    pub fn bind(config: Config) -> Result<BindResult> {
        let endpoint = std::path::absolute(&config.endpoint).with_context(|| {
            format!(
                "failed to resolve the absolute path of endpoint {}",
                config.endpoint.display()
            )
        })?;
        security::ensure_endpoint_fits(&endpoint)?;

        let layout = Layout::prepare(&config.state_root)?;
        let endpoint_directory = endpoint
            .parent()
            .with_context(|| format!("endpoint {} has no parent directory", endpoint.display()))?;
        security::ensure_private_directory(endpoint_directory)?;
        validate_endpoint_location(&layout.root, &endpoint)?;

        let endpoint_file = layout.run.join("endpoint");

        let lock = if config.single_instance {
            match os_glue::acquire_instance_lock(&layout.lock_file())? {
                Some(lock) => Some(lock),
                None => {
                    let endpoint = read_endpoint_file(&endpoint_file).unwrap_or(endpoint);
                    return Ok(BindResult::AlreadyRunning { endpoint });
                }
            }
        } else {
            None
        };

        let token_file = config
            .token_file
            .clone()
            .unwrap_or_else(|| layout.default_token_file());
        let token = resolve_token(&token_file)?;

        let logger = Logger::open(&layout.logs, config.log_level)
            .context("failed to open the structured service log")?;

        remove_stale_socket(&endpoint)?;

        let listener = UnixListener::bind(&endpoint)
            .with_context(|| format!("failed to bind the endpoint {}", endpoint.display()))?;
        listener
            .set_nonblocking(true)
            .context("failed to make the listener non-blocking")?;
        security::set_mode(&endpoint, PRIVATE_FILE_MODE)?;
        write_endpoint_file(&endpoint_file, &endpoint)?;

        let control = Arc::new(Control::new(Instant::now()));
        let context = Arc::new(ServiceContext {
            control: Arc::clone(&control),
            state_root: layout.root.clone(),
            endpoint: endpoint.clone(),
            token,
            token_file: token_file.clone(),
            idempotency: IdempotencyStore::open(layout.run.join("idempotency.json")),
            logger,
            instance_id: security::generate_token(),
            pid: std::process::id(),
            started: Instant::now(),
        });

        Ok(BindResult::Started(Self {
            config,
            endpoint,
            token_file,
            endpoint_file,
            listener,
            control,
            registry: ConnectionRegistry::default(),
            context,
            lock,
            next_connection_id: AtomicU64::new(0),
        }))
    }

    /// The bound endpoint.
    pub fn endpoint(&self) -> &Path {
        &self.endpoint
    }

    /// The token file this service wrote.
    pub fn token_file(&self) -> &Path {
        &self.token_file
    }

    /// A handle another thread can use to request shutdown.
    pub fn handle(&self) -> ServerHandle {
        ServerHandle {
            control: Arc::clone(&self.control),
            registry: self.registry.clone(),
        }
    }

    /// Accept connections until a lifecycle rule fires.
    pub fn run(mut self) -> Result<()> {
        let result = self.accept_loop();
        let reason = self
            .control
            .shutdown_reason()
            .unwrap_or_else(|| "server loop ended".to_string());
        self.control.request_shutdown(reason.clone());

        // `service.shutdown` and parent-gone win over the timers, but a job is
        // still cooperative: request cancellation, then wait up to 10 s for the
        // transport to observe a terminal state before exiting.
        self.stop_running_jobs();

        // Let connection threads flush the response and notification they may
        // have just written, then close whatever is left.
        thread::sleep(SHUTDOWN_FLUSH_GRACE);
        self.registry.shutdown_all();
        let _ = fs::remove_file(&self.endpoint);
        let _ = fs::remove_file(&self.endpoint_file);
        drop(self.lock.take());

        self.context.logger.info(format!("shutting down: {reason}"));
        result
    }

    fn stop_running_jobs(&self) {
        if self.control.shutdown_cancels_jobs() {
            for job_id in self.control.running_job_ids() {
                self.context
                    .logger
                    .info(format!("cancelling running job {job_id} for shutdown"));
                let _ = sportcut_api::job_cancel(job_id);
            }
        }

        let deadline = Instant::now() + SHUTDOWN_WAIT;
        while self.control.running_jobs() > 0 && Instant::now() < deadline {
            thread::sleep(ACCEPT_POLL_INTERVAL);
        }
        if self.control.running_jobs() > 0 {
            self.context.logger.warn(format!(
                "shutdown waited {}s for {} running job(s); exiting anyway",
                SHUTDOWN_WAIT.as_secs(),
                self.control.running_jobs()
            ));
        }
    }

    fn accept_loop(&mut self) -> Result<()> {
        let mut parent_gone_since: Option<Instant> = None;

        loop {
            if self.control.shutdown_requested() {
                break;
            }

            if let Some(parent_pid) = self.config.parent_pid {
                if os_glue::process_alive(parent_pid) {
                    parent_gone_since = None;
                } else {
                    let since = *parent_gone_since.get_or_insert_with(Instant::now);
                    if self.control.running_jobs() > 0 {
                        // §4.6: with a job running, cancellation starts now and
                        // the process waits for a terminal state (up to 10 s).
                        self.control.request_shutdown_cancelling(
                            "parent process is gone; cancelling running jobs",
                        );
                        break;
                    }
                    if since.elapsed() >= Duration::from_secs(self.config.parent_gone_grace_seconds)
                    {
                        self.control.request_shutdown("parent process is gone");
                        break;
                    }
                }
            }

            if let Some(idle) = self.control.idle_elapsed() {
                if idle >= Duration::from_secs(self.config.idle_exit_seconds) {
                    self.control
                        .request_shutdown("idle exit: no connections and no running jobs");
                    break;
                }
            }

            match self.listener.accept() {
                Ok((stream, _address)) => self.spawn_connection(stream),
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                    thread::sleep(ACCEPT_POLL_INTERVAL);
                }
                Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
                Err(error) => {
                    return Err(error).with_context(|| {
                        format!("failed to accept on {}", self.endpoint.display())
                    })
                }
            }
        }

        Ok(())
    }

    fn spawn_connection(&self, stream: UnixStream) {
        if !self.control.try_connection_opened(MAX_CONNECTIONS) {
            self.context.logger.warn(format!(
                "refusing connection: {MAX_CONNECTIONS} connections are already open"
            ));
            let _ = stream.shutdown(Shutdown::Both);
            return;
        }

        match os_glue::peer_uid(&stream) {
            Ok(uid) if uid == os_glue::our_uid() => {}
            Ok(_) => {
                self.control.connection_closed();
                let _ = stream.shutdown(Shutdown::Both);
                return;
            }
            Err(error) => {
                self.context
                    .logger
                    .warn(format!("refusing connection: {error:#}"));
                self.control.connection_closed();
                let _ = stream.shutdown(Shutdown::Both);
                return;
            }
        }

        // Accepted sockets inherit O_NONBLOCK from the listener on BSD/macOS,
        // so reset the connection to blocking before it is served.
        if let Err(error) = stream.set_nonblocking(false) {
            self.context
                .logger
                .warn(format!("failed to make the connection blocking: {error}"));
            self.control.connection_closed();
            let _ = stream.shutdown(Shutdown::Both);
            return;
        }

        let registered = match stream.try_clone() {
            Ok(clone) => clone,
            Err(error) => {
                self.context
                    .logger
                    .warn(format!("failed to clone the accepted socket: {error}"));
                self.control.connection_closed();
                let _ = stream.shutdown(Shutdown::Both);
                return;
            }
        };

        let id = self.next_connection_id.fetch_add(1, Ordering::Relaxed);
        self.registry.insert(id, registered);

        let guard = ConnectionGuard {
            id,
            control: Arc::clone(&self.control),
            registry: self.registry.clone(),
        };
        let context = Arc::clone(&self.context);
        let spawned = thread::Builder::new()
            .name(format!("sportcut-connection-{id}"))
            .spawn(move || {
                let _guard = guard;
                rpc::serve_connection(stream, context);
            });

        if let Err(error) = spawned {
            // Dropping the closure above already ran the guard once the thread
            // builder failed, so the counters and registry are consistent.
            self.context
                .logger
                .warn(format!("failed to start a connection thread: {error}"));
        }
    }
}

/// A cloneable handle for requesting shutdown from another thread.
#[derive(Debug, Clone)]
pub struct ServerHandle {
    control: Arc<Control>,
    registry: ConnectionRegistry,
}

impl ServerHandle {
    /// Request shutdown; running jobs are cancelled cooperatively.
    pub fn shutdown(&self, reason: impl Into<String>) {
        self.control.request_shutdown_cancelling(reason);
        let registry = self.registry.clone();
        let spawned = thread::Builder::new()
            .name("sportcut-shutdown".to_string())
            .spawn(move || {
                thread::sleep(SHUTDOWN_FLUSH_GRACE);
                registry.shutdown_all();
            });
        if let Err(error) = spawned {
            eprintln!("sportcut-service: failed to start the shutdown thread: {error}");
            self.registry.shutdown_all();
        }
    }

    /// Whether shutdown has been requested.
    pub fn is_shutdown_requested(&self) -> bool {
        self.control.shutdown_requested()
    }

    /// The first shutdown reason, if any.
    pub fn shutdown_reason(&self) -> Option<String> {
        self.control.shutdown_reason()
    }

    /// Running jobs the lifecycle currently counts.
    pub fn running_jobs(&self) -> usize {
        self.control.running_jobs()
    }
}

/// Shared lifecycle state.
#[derive(Debug)]
pub struct Control {
    connections: AtomicUsize,
    running_jobs: AtomicUsize,
    /// Running job ids, mapped to their match id, for shutdown cancellation
    /// and for the health snapshot. Guarded together with the counter so the
    /// two never disagree.
    jobs: Mutex<HashMap<String, String>>,
    idle_since: Mutex<Option<Instant>>,
    shutdown: AtomicBool,
    shutdown_reason: Mutex<Option<String>>,
    cancel_running_jobs: AtomicBool,
    last_error: Mutex<Option<String>>,
}

impl Control {
    pub(crate) fn new(now: Instant) -> Self {
        Self {
            connections: AtomicUsize::new(0),
            running_jobs: AtomicUsize::new(0),
            jobs: Mutex::new(HashMap::new()),
            idle_since: Mutex::new(Some(now)),
            shutdown: AtomicBool::new(false),
            shutdown_reason: Mutex::new(None),
            cancel_running_jobs: AtomicBool::new(false),
            last_error: Mutex::new(None),
        }
    }

    fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
        mutex
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Request shutdown without cancelling jobs; the first reason is kept.
    pub fn request_shutdown(&self, reason: impl Into<String>) {
        self.record_shutdown(reason, false);
    }

    /// Request shutdown and cancel every running job.
    pub fn request_shutdown_cancelling(&self, reason: impl Into<String>) {
        self.record_shutdown(reason, true);
    }

    fn record_shutdown(&self, reason: impl Into<String>, cancel_jobs: bool) {
        {
            let mut stored = Self::lock(&self.shutdown_reason);
            if stored.is_none() {
                *stored = Some(reason.into());
            }
        }
        if cancel_jobs {
            self.cancel_running_jobs.store(true, Ordering::SeqCst);
        }
        self.shutdown.store(true, Ordering::SeqCst);
    }

    /// Whether shutdown has been requested.
    pub fn shutdown_requested(&self) -> bool {
        self.shutdown.load(Ordering::SeqCst)
    }

    /// Whether shutdown should cancel running jobs.
    pub fn shutdown_cancels_jobs(&self) -> bool {
        self.cancel_running_jobs.load(Ordering::SeqCst)
    }

    /// The first shutdown reason, if any.
    pub fn shutdown_reason(&self) -> Option<String> {
        Self::lock(&self.shutdown_reason).clone()
    }

    /// Open connection count.
    pub fn connections(&self) -> usize {
        self.connections.load(Ordering::SeqCst)
    }

    /// Running job count.
    pub fn running_jobs(&self) -> usize {
        self.running_jobs.load(Ordering::SeqCst)
    }

    /// Identifiers of the jobs currently counted as running.
    pub fn running_job_ids(&self) -> Vec<String> {
        Self::lock(&self.jobs).keys().cloned().collect()
    }

    /// The last error surfaced by a request, if any.
    pub fn last_error(&self) -> Option<String> {
        Self::lock(&self.last_error).clone()
    }

    /// Remember an error for `service.health`.
    pub fn record_error(&self, message: impl Into<String>) {
        *Self::lock(&self.last_error) = Some(message.into());
    }

    /// How long the process has been idle, or `None` while it is not idle.
    pub fn idle_elapsed(&self) -> Option<Duration> {
        if self.connections() > 0 || self.running_jobs() > 0 {
            return None;
        }
        Self::lock(&self.idle_since).as_ref().map(Instant::elapsed)
    }

    /// Register a connection if the limit allows it.
    fn try_connection_opened(&self, maximum: usize) -> bool {
        let mut current = self.connections.load(Ordering::SeqCst);
        loop {
            if current >= maximum {
                return false;
            }
            match self.connections.compare_exchange_weak(
                current,
                current + 1,
                Ordering::SeqCst,
                Ordering::SeqCst,
            ) {
                Ok(_) => {
                    *Self::lock(&self.idle_since) = None;
                    return true;
                }
                Err(actual) => current = actual,
            }
        }
    }

    fn connection_closed(&self) {
        let previous = self.connections.fetch_sub(1, Ordering::SeqCst);
        if previous == 1 && self.running_jobs() == 0 {
            *Self::lock(&self.idle_since) = Some(Instant::now());
        }
    }

    /// Record that a heavy job started; it blocks idle exit.
    ///
    /// Registering the same job twice is a no-op, so a retried start response
    /// cannot leak a second slot.
    pub fn job_started(&self, job_id: impl Into<String>, match_id: impl Into<String>) {
        let job_id = job_id.into();
        let inserted = Self::lock(&self.jobs)
            .insert(job_id, match_id.into())
            .is_none();
        if inserted {
            self.running_jobs.fetch_add(1, Ordering::SeqCst);
        }
        *Self::lock(&self.idle_since) = None;
    }

    /// Record that a heavy job reached a terminal state.
    pub fn job_finished(&self, job_id: &str) {
        if Self::lock(&self.jobs).remove(job_id).is_none() {
            return;
        }
        let previous = self.running_jobs.fetch_sub(1, Ordering::SeqCst);
        if previous == 1 && self.connections() == 0 {
            *Self::lock(&self.idle_since) = Some(Instant::now());
        }
    }
}

/// Cloned sockets of open connections, so shutdown can interrupt a blocked read.
#[derive(Debug, Clone, Default)]
pub struct ConnectionRegistry {
    streams: Arc<Mutex<HashMap<u64, UnixStream>>>,
}

impl ConnectionRegistry {
    fn insert(&self, id: u64, stream: UnixStream) {
        Control::lock(&self.streams).insert(id, stream);
    }

    fn remove(&self, id: u64) {
        Control::lock(&self.streams).remove(&id);
    }

    /// Shut down every registered stream, waking blocked readers.
    pub fn shutdown_all(&self) {
        let streams = Control::lock(&self.streams);
        for stream in streams.values() {
            let _ = stream.shutdown(Shutdown::Both);
        }
    }
}

#[derive(Debug)]
struct ConnectionGuard {
    id: u64,
    control: Arc<Control>,
    registry: ConnectionRegistry,
}

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        self.registry.remove(self.id);
        self.control.connection_closed();
    }
}

/// Immutable service identity shared with every connection.
pub struct ServiceContext {
    /// Lifecycle state.
    pub control: Arc<Control>,
    /// Absolute state root.
    pub state_root: PathBuf,
    /// Absolute endpoint.
    pub endpoint: PathBuf,
    /// Token loaded at start; the token file is authoritative afterwards.
    pub token: String,
    /// File the app regenerates on every launch.
    pub token_file: PathBuf,
    /// Durable and in-memory `clientRequestId` results.
    pub idempotency: IdempotencyStore,
    /// Structured local log.
    pub logger: Logger,
    /// Random identity of this process.
    pub instance_id: String,
    /// Operating-system process id.
    pub pid: u32,
    /// When the service bound its endpoint.
    pub started: Instant,
}

impl fmt::Debug for ServiceContext {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ServiceContext")
            .field("state_root", &self.state_root)
            .field("endpoint", &self.endpoint)
            .field("token", &"<redacted>")
            .field("token_file", &self.token_file)
            .field("instance_id", &self.instance_id)
            .field("pid", &self.pid)
            .finish_non_exhaustive()
    }
}

impl ServiceContext {
    /// The token to compare at handshake time.
    ///
    /// The app regenerates the token on every launch and rewrites the file, so
    /// the file is read for every handshake. A relaunch while the service is
    /// still alive therefore authenticates with the new token without a
    /// restart; the in-memory token is the fallback when the file is missing.
    pub fn current_token(&self) -> String {
        fs::read_to_string(&self.token_file)
            .ok()
            .map(|contents| contents.trim().to_string())
            .filter(|token| !token.is_empty())
            .unwrap_or_else(|| self.token.clone())
    }

    /// A context with the documented test defaults.
    #[cfg(test)]
    pub fn for_tests(root: &Path) -> Self {
        let run = root.join("run");
        Self {
            control: Arc::new(Control::new(Instant::now())),
            state_root: root.to_path_buf(),
            endpoint: run.join("s.sock"),
            token: "token".to_string(),
            token_file: run.join("token"),
            idempotency: IdempotencyStore::in_memory(),
            logger: Logger::disabled(),
            instance_id: "instance-1".to_string(),
            pid: 42,
            started: Instant::now(),
        }
    }

    /// The handshake's `service` object.
    pub fn service_info(&self) -> ServiceInfo {
        ServiceInfo {
            name: SERVICE_NAME.to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            build: service_build().to_string(),
            instance_id: self.instance_id.clone(),
            pid: self.pid,
        }
    }

    /// The handshake's `paths` object.
    pub fn paths(&self) -> ServicePaths {
        ServicePaths {
            recordings: path_string(&self.state_root.join("recordings")),
            matches: path_string(&self.state_root.join("matches")),
            render_inputs: path_string(&self.state_root.join("render-inputs")),
        }
    }

    /// Milliseconds since the endpoint was bound.
    pub fn uptime_ms(&self) -> u64 {
        u64::try_from(self.started.elapsed().as_millis()).unwrap_or(u64::MAX)
    }

    /// The state root as the handshake reports it.
    pub fn state_root_string(&self) -> String {
        path_string(&self.state_root)
    }

    /// The endpoint as the handshake reports it.
    pub fn endpoint_string(&self) -> String {
        path_string(&self.endpoint)
    }
}

fn path_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

/// Load the per-launch token.
///
/// The app owns the token: it writes `<state-root>/run/token` and may also pass
/// `SPORTCUT_SERVICE_TOKEN` in the launch environment. An existing token file
/// wins over generating a new one, so a relaunch of the app does not invalidate
/// a still-running service.
fn resolve_token(token_file: &Path) -> Result<String> {
    if let Ok(value) = std::env::var(TOKEN_ENV) {
        let token = value.trim();
        if !token.is_empty() {
            security::write_token_file(token_file, token)?;
            return Ok(token.to_string());
        }
    }

    if let Ok(contents) = fs::read_to_string(token_file) {
        let token = contents.trim();
        if !token.is_empty() {
            security::set_mode(token_file, PRIVATE_FILE_MODE)?;
            return Ok(token.to_string());
        }
    }

    let token = security::generate_token();
    security::write_token_file(token_file, &token)?;
    Ok(token)
}

fn read_endpoint_file(path: &Path) -> Option<PathBuf> {
    let contents = fs::read_to_string(path).ok()?;
    let contents = contents.trim();
    (!contents.is_empty()).then(|| PathBuf::from(contents))
}

fn write_endpoint_file(path: &Path, endpoint: &Path) -> Result<()> {
    if let Some(parent) = path.parent() {
        security::ensure_private_directory(parent)?;
    }
    let temporary = path.with_extension(format!("tmp.{}", std::process::id()));
    fs::write(&temporary, endpoint.as_os_str().as_encoded_bytes())
        .with_context(|| format!("failed to write {}", temporary.display()))?;
    security::set_mode(&temporary, PRIVATE_FILE_MODE)?;
    fs::rename(&temporary, path)
        .with_context(|| format!("failed to publish {}", path.display()))?;
    Ok(())
}

/// Require the endpoint to sit inside the state root or the app container.
///
/// Protocol §1.1: the socket must remain reachable under the sandbox, so it is
/// either under the state root, its parent (the non-sandboxed
/// Application Support layout), or the `Library/Containers/<bundle>` root that
/// contains the state root.
fn validate_endpoint_location(state_root: &Path, endpoint: &Path) -> Result<()> {
    if endpoint
        .components()
        .any(|component| matches!(component, Component::ParentDir))
    {
        bail!(
            "endpoint {} must not contain parent-directory components",
            endpoint.display()
        );
    }

    let parent = endpoint
        .parent()
        .with_context(|| format!("endpoint {} has no parent directory", endpoint.display()))?;
    let canonical_parent = fs::canonicalize(parent).with_context(|| {
        format!(
            "failed to resolve the endpoint directory {}",
            parent.display()
        )
    })?;
    let file_name = endpoint.file_name().with_context(|| {
        format!(
            "endpoint {} does not name a socket file",
            endpoint.display()
        )
    })?;
    let resolved = canonical_parent.join(file_name);

    let canonical_root = fs::canonicalize(state_root).unwrap_or_else(|_| state_root.to_path_buf());
    let mut allowed = vec![canonical_root.clone()];
    if let Some(parent) = canonical_root.parent() {
        allowed.push(parent.to_path_buf());
    }
    if let Some(container) = container_root(&canonical_root) {
        allowed.push(container);
    }

    if !allowed.iter().any(|root| resolved.starts_with(root)) {
        bail!(
            "endpoint {} must be inside the service state root {} or the app container",
            endpoint.display(),
            canonical_root.display()
        );
    }
    Ok(())
}

fn container_root(path: &Path) -> Option<PathBuf> {
    let components: Vec<_> = path.components().collect();
    let index = components
        .iter()
        .position(|component| component.as_os_str() == "Containers")?;
    let bundle = components.get(index + 1)?;
    if !matches!(bundle, Component::Normal(_)) {
        return None;
    }
    let mut root = PathBuf::new();
    for component in &components[..=index + 1] {
        root.push(component.as_os_str());
    }
    Some(root)
}

/// Remove a stale socket, but never unlink one a live process is listening on.
fn remove_stale_socket(endpoint: &Path) -> Result<()> {
    let metadata = match fs::symlink_metadata(endpoint) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(error) => {
            return Err(error)
                .with_context(|| format!("failed to inspect the endpoint {}", endpoint.display()))
        }
    };

    if !metadata.file_type().is_socket() {
        bail!(
            "the endpoint path {} already exists and is not a socket; remove it or choose \
             another --endpoint",
            endpoint.display()
        );
    }

    match UnixStream::connect(endpoint) {
        Ok(_) => bail!(
            "endpoint_in_use: another service is already listening on {}",
            endpoint.display()
        ),
        Err(error)
            if error.kind() == io::ErrorKind::ConnectionRefused
                || error.kind() == io::ErrorKind::NotFound =>
        {
            fs::remove_file(endpoint).with_context(|| {
                format!("failed to remove the stale socket {}", endpoint.display())
            })
        }
        Err(error) => Err(error).with_context(|| {
            format!(
                "failed to determine whether the socket {} is live",
                endpoint.display()
            )
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::Config;

    #[test]
    fn a_stale_socket_is_removed_and_a_live_one_is_kept() {
        let directory = tempfile::tempdir().expect("temp dir");
        let endpoint = directory.path().join("s.sock");

        // A bound-but-dropped listener leaves a stale socket file behind.
        {
            let listener = UnixListener::bind(&endpoint).expect("bind");
            drop(listener);
        }
        assert!(endpoint.exists());
        remove_stale_socket(&endpoint).expect("stale socket removed");
        assert!(!endpoint.exists());

        let listener = UnixListener::bind(&endpoint).expect("bind");
        let error = remove_stale_socket(&endpoint).expect_err("live socket is not removed");
        assert!(format!("{error:#}").contains("endpoint_in_use"));
        drop(listener);
    }

    #[test]
    fn a_non_socket_at_the_endpoint_is_refused() {
        let directory = tempfile::tempdir().expect("temp dir");
        let endpoint = directory.path().join("s.sock");
        fs::write(&endpoint, b"not a socket").expect("write file");

        let error = remove_stale_socket(&endpoint).expect_err("regular file refused");
        assert!(format!("{error:#}").contains("is not a socket"));
        assert!(endpoint.exists());
    }

    #[test]
    fn idle_elapsed_starts_only_when_no_connection_is_open() {
        let control = Control::new(Instant::now());
        assert!(control.idle_elapsed().is_some());

        assert!(control.try_connection_opened(MAX_CONNECTIONS));
        assert!(control.idle_elapsed().is_none());

        control.job_started("job-1", "match-1");
        control.connection_closed();
        assert!(
            control.idle_elapsed().is_none(),
            "a running job blocks idle exit"
        );
        assert_eq!(control.running_job_ids(), vec!["job-1".to_string()]);

        control.job_finished("job-1");
        assert!(control.idle_elapsed().is_some());
        assert_eq!(control.running_jobs(), 0);
    }

    #[test]
    fn job_registration_is_idempotent_and_never_underflows() {
        let control = Control::new(Instant::now());
        control.job_started("job-1", "match-1");
        control.job_started("job-1", "match-1");
        assert_eq!(control.running_jobs(), 1);

        control.job_finished("job-1");
        control.job_finished("job-1");
        control.job_finished("job-that-never-started");
        assert_eq!(control.running_jobs(), 0);
    }

    #[test]
    fn the_connection_limit_is_enforced() {
        let control = Control::new(Instant::now());
        assert!(control.try_connection_opened(2));
        assert!(control.try_connection_opened(2));
        assert!(
            !control.try_connection_opened(2),
            "the third connection is refused"
        );
        assert_eq!(control.connections(), 2);

        control.connection_closed();
        assert!(control.try_connection_opened(2), "a freed slot is reused");
    }

    #[test]
    fn the_first_shutdown_reason_wins_and_cancellation_is_sticky() {
        let control = Control::new(Instant::now());
        control.request_shutdown("first");
        control.request_shutdown_cancelling("second");
        assert!(control.shutdown_requested());
        assert_eq!(control.shutdown_reason().as_deref(), Some("first"));
        assert!(control.shutdown_cancels_jobs());
    }

    #[test]
    fn the_endpoint_must_be_inside_the_state_root_or_container() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        fs::create_dir_all(&state_root).expect("state root");

        // Under the state root.
        let under = state_root.join("run");
        fs::create_dir_all(&under).expect("run");
        validate_endpoint_location(&state_root, &under.join("s.sock"))
            .expect("under the state root");

        // A sibling of the state root, the non-sandboxed Application Support
        // layout, is also allowed.
        let sibling = directory.path().join("run");
        fs::create_dir_all(&sibling).expect("sibling run");
        validate_endpoint_location(&state_root, &sibling.join("s.sock"))
            .expect("sibling of the state root");

        // An unrelated root is refused.
        let elsewhere = tempfile::tempdir().expect("other temp dir");
        let error = validate_endpoint_location(&state_root, &elsewhere.path().join("s.sock"))
            .expect_err("unrelated endpoint");
        assert!(format!("{error:#}").contains("must be inside"), "{error:#}");
    }

    #[test]
    fn a_second_launch_reports_the_existing_endpoint() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        let first_endpoint = state_root.join("run").join("s.sock");
        let second_endpoint = directory.path().join("run").join("other.sock");

        let first = match Server::bind(Config::new(state_root.clone(), first_endpoint.clone()))
            .expect("first bind")
        {
            BindResult::Started(server) => server,
            BindResult::AlreadyRunning { .. } => panic!("first bind must start"),
        };

        match Server::bind(Config::new(state_root, second_endpoint)).expect("second bind") {
            BindResult::AlreadyRunning { endpoint } => {
                assert_eq!(
                    endpoint,
                    std::path::absolute(&first_endpoint).expect("absolute"),
                    "the running instance's endpoint is reported, not the requested one"
                );
            }
            BindResult::Started(_) => panic!("the lock is already held"),
        }
        drop(first);
    }

    #[test]
    fn an_existing_token_file_is_not_regenerated() {
        let directory = tempfile::tempdir().expect("temp dir");
        let token_file = directory.path().join("run").join("token");
        security::write_token_file(&token_file, "app-generated-token").expect("write token");

        let token = resolve_token(&token_file).expect("resolve");
        assert_eq!(token, "app-generated-token");
        assert_eq!(
            fs::read_to_string(&token_file).expect("read"),
            "app-generated-token"
        );
    }

    #[test]
    fn a_config_with_a_too_long_endpoint_is_refused_before_binding() {
        let directory = tempfile::tempdir().expect("temp dir");
        let state_root = directory.path().join("state");
        let endpoint = directory.path().join("x".repeat(120));
        let config = Config::new(state_root.clone(), endpoint.clone());

        let error = match Server::bind(config) {
            Ok(_) => panic!("binding should fail"),
            Err(error) => error,
        };
        let message = format!("{error:#}");
        assert!(message.contains("endpoint_too_long"), "{message}");
        assert!(message.contains("103"), "{message}");
        assert!(!endpoint.exists());
    }
}
