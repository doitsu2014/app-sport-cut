//! `clientRequestId` deduplication, protocol §3.1.
//!
//! Two stores share one key space:
//!
//! - a bounded in-memory cache of the last 1,024 lightweight mutations for ten
//!   minutes, and
//! - a durable key → result map for mutations that start a job. The durable
//!   map survives a service restart, so a retry after a lost response returns
//!   the existing handle instead of creating a second import or export.
//!
//! A repeated key with a different method is a client bug: the service reports
//! `invalid_params` rather than returning a result for another operation.

use std::collections::{BTreeMap, VecDeque};
use std::fs;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// How many lightweight results are retained.
pub const LIGHTWEIGHT_LIMIT: usize = 1_024;

/// How long a lightweight result stays valid.
pub const LIGHTWEIGHT_TTL: Duration = Duration::from_secs(10 * 60);

/// The outcome of looking up a `clientRequestId`.
#[derive(Debug, Clone, PartialEq)]
pub enum Lookup {
    /// The key was already seen for this method; return the stored result.
    Hit(Value),
    /// The key is unknown (or expired); perform the mutation.
    Miss,
    /// The key was seen for a different method.
    Conflict,
}

/// A cloneable idempotency store shared by every connection.
#[derive(Debug, Clone)]
pub struct IdempotencyStore {
    inner: Arc<Inner>,
}

#[derive(Debug)]
struct Inner {
    /// Durable backing file, or `None` for an in-memory test store.
    path: Option<PathBuf>,
    state: Mutex<State>,
}

#[derive(Debug, Default)]
struct State {
    lightweight: VecDeque<LightweightEntry>,
    durable: BTreeMap<String, DurableEntry>,
}

#[derive(Debug)]
struct LightweightEntry {
    key: String,
    method: String,
    result: Value,
    recorded: Instant,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DurableEntry {
    method: String,
    result: Value,
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct Persisted {
    #[serde(default)]
    entries: BTreeMap<String, DurableEntry>,
}

impl IdempotencyStore {
    /// An in-memory store, used by tests.
    pub fn in_memory() -> Self {
        Self {
            inner: Arc::new(Inner {
                path: None,
                state: Mutex::new(State::default()),
            }),
        }
    }

    /// Open the durable store at `path`, loading any existing entries.
    ///
    /// A corrupt or unreadable file is treated as empty: idempotency is a
    /// safety net, and refusing to start over a damaged cache would be worse
    /// than losing a retry key.
    pub fn open(path: PathBuf) -> Self {
        let durable = load(&path);
        Self {
            inner: Arc::new(Inner {
                path: Some(path),
                state: Mutex::new(State {
                    lightweight: VecDeque::new(),
                    durable,
                }),
            }),
        }
    }

    fn lock(&self) -> MutexGuard<'_, State> {
        self.inner
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Look up a key, confined to the method that supplied it.
    pub fn lookup(&self, key: &str, method: &str) -> Lookup {
        let mut state = self.lock();
        if let Some(entry) = state.durable.get(key) {
            return if entry.method == method {
                Lookup::Hit(entry.result.clone())
            } else {
                Lookup::Conflict
            };
        }

        let now = Instant::now();
        while state
            .lightweight
            .back()
            .is_some_and(|entry| now.duration_since(entry.recorded) > LIGHTWEIGHT_TTL)
        {
            state.lightweight.pop_back();
        }
        if let Some(index) = state.lightweight.iter().position(|entry| entry.key == key) {
            let entry = &state.lightweight[index];
            return if entry.method == method {
                Lookup::Hit(entry.result.clone())
            } else {
                Lookup::Conflict
            };
        }
        Lookup::Miss
    }

    /// Record a job-starting mutation durably.
    ///
    /// The write happens while the state lock is held so two concurrent
    /// retries cannot persist an older snapshot over a newer one.
    pub fn record_job_start(&self, key: &str, method: &str, result: Value) {
        let mut state = self.lock();
        state.durable.insert(
            key.to_string(),
            DurableEntry {
                method: method.to_string(),
                result,
            },
        );
        if let Some(path) = self.inner.path.as_ref() {
            let _ = persist(path, &state.durable);
        }
    }

    /// Record a lightweight mutation in the bounded, expiring cache.
    pub fn record_lightweight(&self, key: &str, method: &str, result: Value) {
        let mut state = self.lock();
        state.lightweight.retain(|entry| entry.key != key);
        state.lightweight.push_front(LightweightEntry {
            key: key.to_string(),
            method: method.to_string(),
            result,
            recorded: Instant::now(),
        });
        while state.lightweight.len() > LIGHTWEIGHT_LIMIT {
            state.lightweight.pop_back();
        }
    }

    /// Whether a method starts a long-running job and therefore needs a
    /// durable key.
    pub fn is_job_start(method: &str) -> bool {
        matches!(
            method,
            "engine.import.start"
                | "engine.regenerate.start"
                | "engine.rally.start"
                | "engine.tracking.start"
                | "engine.export.start"
                | "library.match.import"
                | "library.match.adopt"
                | "library.recording.relocate"
                | "library.catalog.adoptLegacy"
        )
    }

    /// Whether a method mutates state and accepts a `clientRequestId`.
    pub fn is_mutating(method: &str) -> bool {
        Self::is_job_start(method) || method == "engine.calibration.save"
    }
}

fn load(path: &Path) -> BTreeMap<String, DurableEntry> {
    let Ok(bytes) = fs::read(path) else {
        return BTreeMap::new();
    };
    serde_json::from_slice::<Persisted>(&bytes)
        .map(|persisted| persisted.entries)
        .unwrap_or_default()
}

fn persist(path: &Path, entries: &BTreeMap<String, DurableEntry>) -> std::io::Result<()> {
    let Some(parent) = path.parent() else {
        return Ok(());
    };
    fs::create_dir_all(parent)?;
    let mut temporary = path.as_os_str().to_owned();
    temporary.push(format!(".tmp.{}", std::process::id()));
    let temporary = PathBuf::from(temporary);

    let persisted = Persisted {
        entries: entries.clone(),
    };
    let bytes = serde_json::to_vec(&persisted).map_err(std::io::Error::other)?;
    let result = (|| {
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&temporary)?;
        use std::io::Write as _;
        file.write_all(&bytes)?;
        file.sync_all()?;
        drop(file);
        fs::rename(&temporary, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn repeated_keys_return_the_stored_result() {
        let store = IdempotencyStore::in_memory();
        assert_eq!(store.lookup("key-1", "engine.import.start"), Lookup::Miss);

        store.record_job_start("key-1", "engine.import.start", json!({ "jobId": "job-1" }));
        assert_eq!(
            store.lookup("key-1", "engine.import.start"),
            Lookup::Hit(json!({ "jobId": "job-1" }))
        );
        // A different mutating method with the same key is a client bug.
        assert_eq!(
            store.lookup("key-1", "engine.export.start"),
            Lookup::Conflict
        );
    }

    #[test]
    fn lightweight_keys_are_bounded() {
        let store = IdempotencyStore::in_memory();
        for index in 0..(LIGHTWEIGHT_LIMIT + 5) {
            store.record_lightweight(
                &format!("key-{index}"),
                "engine.calibration.save",
                json!({ "index": index }),
            );
        }
        // The oldest entries are evicted.
        assert_eq!(
            store.lookup("key-0", "engine.calibration.save"),
            Lookup::Miss
        );
        assert!(matches!(
            store.lookup(
                &format!("key-{}", LIGHTWEIGHT_LIMIT + 4),
                "engine.calibration.save"
            ),
            Lookup::Hit(_)
        ));
    }

    #[test]
    fn job_start_keys_survive_a_reopen() {
        let directory = tempfile::tempdir().expect("temp dir");
        let path = directory.path().join("run").join("idempotency.json");

        let store = IdempotencyStore::open(path.clone());
        store.record_job_start(
            "key-1",
            "engine.import.start",
            json!({ "jobId": "job-1", "matchId": "match-1" }),
        );

        let reopened = IdempotencyStore::open(path);
        assert_eq!(
            reopened.lookup("key-1", "engine.import.start"),
            Lookup::Hit(json!({ "jobId": "job-1", "matchId": "match-1" }))
        );
    }

    #[test]
    fn a_corrupt_store_loads_empty() {
        let directory = tempfile::tempdir().expect("temp dir");
        let path = directory.path().join("idempotency.json");
        fs::write(&path, b"not json").expect("write");
        let store = IdempotencyStore::open(path);
        assert_eq!(store.lookup("key", "engine.import.start"), Lookup::Miss);
    }

    #[test]
    fn mutating_methods_are_classified() {
        assert!(IdempotencyStore::is_mutating("engine.import.start"));
        assert!(IdempotencyStore::is_mutating("engine.calibration.save"));
        assert!(!IdempotencyStore::is_mutating("engine.probe"));
        assert!(!IdempotencyStore::is_mutating("engine.job.status"));
        assert!(IdempotencyStore::is_job_start("engine.export.start"));
        assert!(!IdempotencyStore::is_job_start("engine.calibration.save"));
    }
}
