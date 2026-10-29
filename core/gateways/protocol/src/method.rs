//! Frozen protocol method names.
//!
//! Method names are part of the major-version contract: renaming or removing
//! one is a breaking change (protocol §12). Every constant here appears
//! verbatim in `docs/architecture/protocol.md`.

// Service lifecycle methods, protocol §4.

/// Handshake; must be the first request on a connection.
pub const SERVICE_HELLO: &str = "service.hello";
/// Health and current catalog/job state; callable during a heavy job.
pub const SERVICE_HEALTH: &str = "service.health";
/// Build metadata, state root, and protocol range.
pub const SERVICE_INFO: &str = "service.info";
/// In-memory counters; optional under the `metrics.v1` capability.
pub const SERVICE_METRICS: &str = "service.metrics";
/// Cheap liveness check.
pub const SERVICE_PING: &str = "service.ping";
/// Build the local diagnostics bundle.
pub const SERVICE_DIAGNOSTICS: &str = "service.diagnostics";
/// Request shutdown; also the name of the shutdown notification.
pub const SERVICE_SHUTDOWN: &str = "service.shutdown";

// Engine facade methods, protocol §5. These map one-to-one to the 17 calls in
// `core/adapters/api/src/facade.rs`.

/// 1. The stages a media import runs, in order.
pub const ENGINE_IMPORT_STAGES: &str = "engine.importStages";
/// 2. Read recording metadata.
pub const ENGINE_PROBE: &str = "engine.probe";
/// 3. Start the media import job.
pub const ENGINE_IMPORT_START: &str = "engine.import.start";
/// 4. Start regenerating missing media artifacts.
pub const ENGINE_REGENERATE_START: &str = "engine.regenerate.start";
/// 5. Start rally segmentation.
pub const ENGINE_RALLY_START: &str = "engine.rally.start";
/// 6. Read current rally suggestions.
pub const ENGINE_RALLY_SUGGESTIONS: &str = "engine.rally.suggestions";
/// 7. Read a bounded player-track window.
pub const ENGINE_TRACKS_WINDOW: &str = "engine.tracks.window";
/// 8. Start player tracking.
pub const ENGINE_TRACKING_START: &str = "engine.tracking.start";
/// 9. Read job status.
pub const ENGINE_JOB_STATUS: &str = "engine.job.status";
/// 10. Rank rallies for a highlight reel.
pub const ENGINE_HIGHLIGHT_RANK: &str = "engine.highlight.rank";
/// 11. Derive serving sides.
pub const ENGINE_SERVING_SIDES: &str = "engine.servingSides";
/// 12. Derive court geometry from a calibration segment.
pub const ENGINE_COURT_GEOMETRY: &str = "engine.court.geometry";
/// 13. Store a match court calibration.
pub const ENGINE_CALIBRATION_SAVE: &str = "engine.calibration.save";
/// 14. Read a match court calibration.
pub const ENGINE_CALIBRATION_GET: &str = "engine.calibration.get";
/// 15. Cancel a job.
pub const ENGINE_JOB_CANCEL: &str = "engine.job.cancel";
/// 16. Start a highlight export.
pub const ENGINE_EXPORT_START: &str = "engine.export.start";
/// 17. Read a match artifact manifest.
pub const ENGINE_MANIFEST: &str = "engine.manifest";

// Catalog, custody, and editing-record methods, protocol §6. They are frozen
// here so the client and the service share the exact names even though the
// Phase 0-1 service does not serve them yet.

/// List workspaces.
pub const LIBRARY_WORKSPACE_LIST: &str = "library.workspace.list";
/// Create a workspace.
pub const LIBRARY_WORKSPACE_CREATE: &str = "library.workspace.create";
/// Rename a workspace.
pub const LIBRARY_WORKSPACE_UPDATE: &str = "library.workspace.update";
/// Delete a workspace and its matches.
pub const LIBRARY_WORKSPACE_DELETE: &str = "library.workspace.delete";
/// List matches.
pub const LIBRARY_MATCH_LIST: &str = "library.match.list";
/// Read one match.
pub const LIBRARY_MATCH_GET: &str = "library.match.get";
/// Import a recording into custody.
pub const LIBRARY_MATCH_IMPORT: &str = "library.match.import";
/// Adopt a recording from the inbox handoff.
pub const LIBRARY_MATCH_ADOPT: &str = "library.match.adopt";
/// Update a match's mutable fields.
pub const LIBRARY_MATCH_UPDATE: &str = "library.match.update";
/// Delete a match.
pub const LIBRARY_MATCH_DELETE: &str = "library.match.delete";
/// Read a playback path.
pub const LIBRARY_RECORDING_PATH: &str = "library.recording.path";
/// Check whether a recording is available.
pub const LIBRARY_RECORDING_AVAILABLE: &str = "library.recording.available";
/// Relocate a missing recording.
pub const LIBRARY_RECORDING_RELOCATE: &str = "library.recording.relocate";
/// List rallies.
pub const LIBRARY_RALLY_LIST: &str = "library.rally.list";
/// Save a rally.
pub const LIBRARY_RALLY_SAVE: &str = "library.rally.save";
/// Delete a rally.
pub const LIBRARY_RALLY_DELETE: &str = "library.rally.delete";
/// List suggestion decisions.
pub const LIBRARY_SUGGESTION_LIST: &str = "library.suggestion.list";
/// Accept a suggestion.
pub const LIBRARY_SUGGESTION_ACCEPT: &str = "library.suggestion.accept";
/// Dismiss a suggestion.
pub const LIBRARY_SUGGESTION_DISMISS: &str = "library.suggestion.dismiss";
/// List clips.
pub const LIBRARY_CLIP_LIST: &str = "library.clip.list";
/// Save a clip.
pub const LIBRARY_CLIP_SAVE: &str = "library.clip.save";
/// Delete a clip.
pub const LIBRARY_CLIP_DELETE: &str = "library.clip.delete";
/// Reorder clips.
pub const LIBRARY_CLIP_REORDER: &str = "library.clip.reorder";
/// List score events.
pub const LIBRARY_SCORE_LIST: &str = "library.score.list";
/// Replace score events.
pub const LIBRARY_SCORE_REPLACE: &str = "library.score.replace";
/// Read export settings.
pub const LIBRARY_EXPORT_SETTINGS_GET: &str = "library.exportSettings.get";
/// Write export settings.
pub const LIBRARY_EXPORT_SETTINGS_PUT: &str = "library.exportSettings.put";
/// Allocate a render-input directory.
pub const LIBRARY_RENDER_INPUTS_ALLOCATE: &str = "library.renderInputs.allocate";
/// Summarize match scores.
pub const LIBRARY_SUMMARY_SCORES: &str = "library.summary.scores";
/// Summarize clip counts.
pub const LIBRARY_SUMMARY_CLIP_COUNTS: &str = "library.summary.clipCounts";
/// Save a calibration through the catalog composite.
pub const LIBRARY_CALIBRATION_SAVE: &str = "library.calibration.save";
/// Read a calibration through the catalog composite.
pub const LIBRARY_CALIBRATION_GET: &str = "library.calibration.get";
/// Read catalog adoption state.
pub const LIBRARY_CATALOG_STATUS: &str = "library.catalog.status";
/// Adopt a legacy catalog.
pub const LIBRARY_CATALOG_ADOPT_LEGACY: &str = "library.catalog.adoptLegacy";
/// Read legacy adoption progress.
pub const LIBRARY_CATALOG_ADOPT_STATUS: &str = "library.catalog.adoptStatus";

// Notification methods, protocol §3.3.

/// A job reports progress.
pub const JOB_PROGRESS: &str = "job.progress";
/// A job changes lifecycle state.
pub const JOB_STATE: &str = "job.state";
/// A catalog mutation commits.
pub const CATALOG_CHANGED: &str = "catalog.changed";

/// All `service.*` request methods, in protocol §4 order.
pub const SERVICE_METHODS: [&str; 7] = [
    SERVICE_HELLO,
    SERVICE_HEALTH,
    SERVICE_INFO,
    SERVICE_METRICS,
    SERVICE_PING,
    SERVICE_DIAGNOSTICS,
    SERVICE_SHUTDOWN,
];

/// All 17 engine facade methods, in protocol §5 table order.
pub const ENGINE_METHODS: [&str; 17] = [
    ENGINE_IMPORT_STAGES,
    ENGINE_PROBE,
    ENGINE_IMPORT_START,
    ENGINE_REGENERATE_START,
    ENGINE_RALLY_START,
    ENGINE_RALLY_SUGGESTIONS,
    ENGINE_TRACKS_WINDOW,
    ENGINE_TRACKING_START,
    ENGINE_JOB_STATUS,
    ENGINE_HIGHLIGHT_RANK,
    ENGINE_SERVING_SIDES,
    ENGINE_COURT_GEOMETRY,
    ENGINE_CALIBRATION_SAVE,
    ENGINE_CALIBRATION_GET,
    ENGINE_JOB_CANCEL,
    ENGINE_EXPORT_START,
    ENGINE_MANIFEST,
];

/// All `library.*` request methods, in protocol §6 table order.
pub const LIBRARY_METHODS: [&str; 35] = [
    LIBRARY_WORKSPACE_LIST,
    LIBRARY_WORKSPACE_CREATE,
    LIBRARY_WORKSPACE_UPDATE,
    LIBRARY_WORKSPACE_DELETE,
    LIBRARY_MATCH_LIST,
    LIBRARY_MATCH_GET,
    LIBRARY_MATCH_IMPORT,
    LIBRARY_MATCH_ADOPT,
    LIBRARY_MATCH_UPDATE,
    LIBRARY_MATCH_DELETE,
    LIBRARY_RECORDING_PATH,
    LIBRARY_RECORDING_AVAILABLE,
    LIBRARY_RECORDING_RELOCATE,
    LIBRARY_RALLY_LIST,
    LIBRARY_RALLY_SAVE,
    LIBRARY_RALLY_DELETE,
    LIBRARY_SUGGESTION_LIST,
    LIBRARY_SUGGESTION_ACCEPT,
    LIBRARY_SUGGESTION_DISMISS,
    LIBRARY_CLIP_LIST,
    LIBRARY_CLIP_SAVE,
    LIBRARY_CLIP_DELETE,
    LIBRARY_CLIP_REORDER,
    LIBRARY_SCORE_LIST,
    LIBRARY_SCORE_REPLACE,
    LIBRARY_EXPORT_SETTINGS_GET,
    LIBRARY_EXPORT_SETTINGS_PUT,
    LIBRARY_RENDER_INPUTS_ALLOCATE,
    LIBRARY_SUMMARY_SCORES,
    LIBRARY_SUMMARY_CLIP_COUNTS,
    LIBRARY_CALIBRATION_SAVE,
    LIBRARY_CALIBRATION_GET,
    LIBRARY_CATALOG_STATUS,
    LIBRARY_CATALOG_ADOPT_LEGACY,
    LIBRARY_CATALOG_ADOPT_STATUS,
];

/// All notification methods, in protocol §3.3 order.
pub const NOTIFICATION_METHODS: [&str; 4] =
    [JOB_PROGRESS, JOB_STATE, CATALOG_CHANGED, SERVICE_SHUTDOWN];

/// The capability a method requires, or `None` for lifecycle methods.
///
/// Protocol §12: a method is callable only when its capability is in the
/// negotiated intersection. `service.hello`, `health`, `info`, `ping`, and
/// `shutdown` are lifecycle methods and need no capability; every engine
/// method requires `engine.v1`, the `library.*` methods require `catalog.v1`,
/// and the optional service methods require their own capability.
pub fn required_capability(method: &str) -> Option<&'static str> {
    if ENGINE_METHODS.contains(&method) {
        Some(crate::version::capability::ENGINE_V1)
    } else if LIBRARY_METHODS.contains(&method) {
        Some(crate::version::capability::CATALOG_V1)
    } else if method == SERVICE_METRICS {
        Some(crate::version::capability::METRICS_V1)
    } else if method == SERVICE_DIAGNOSTICS {
        Some(crate::version::capability::DIAGNOSTICS_V1)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use super::*;

    #[test]
    fn service_method_names_are_stable() {
        assert_eq!(
            SERVICE_METHODS,
            [
                "service.hello",
                "service.health",
                "service.info",
                "service.metrics",
                "service.ping",
                "service.diagnostics",
                "service.shutdown",
            ]
        );
    }

    #[test]
    fn engine_method_names_are_stable_and_numbered_seventeen() {
        assert_eq!(
            ENGINE_METHODS,
            [
                "engine.importStages",
                "engine.probe",
                "engine.import.start",
                "engine.regenerate.start",
                "engine.rally.start",
                "engine.rally.suggestions",
                "engine.tracks.window",
                "engine.tracking.start",
                "engine.job.status",
                "engine.highlight.rank",
                "engine.servingSides",
                "engine.court.geometry",
                "engine.calibration.save",
                "engine.calibration.get",
                "engine.job.cancel",
                "engine.export.start",
                "engine.manifest",
            ]
        );
        assert_eq!(ENGINE_METHODS.len(), 17);
    }

    #[test]
    fn notification_method_names_are_stable() {
        assert_eq!(
            NOTIFICATION_METHODS,
            [
                "job.progress",
                "job.state",
                "catalog.changed",
                "service.shutdown"
            ]
        );
    }

    #[test]
    fn request_methods_are_unique() {
        let request_methods = SERVICE_METHODS
            .iter()
            .chain(ENGINE_METHODS.iter())
            .chain(LIBRARY_METHODS.iter())
            .collect::<Vec<_>>();
        let unique = request_methods.iter().collect::<HashSet<_>>();
        assert_eq!(unique.len(), request_methods.len());
    }

    #[test]
    fn library_method_names_freeze_the_v1_surface() {
        assert_eq!(LIBRARY_METHODS.len(), 35);
        assert!(LIBRARY_METHODS.contains(&"library.match.import"));
        assert!(LIBRARY_METHODS.contains(&"library.renderInputs.allocate"));
        assert!(LIBRARY_METHODS.contains(&"library.catalog.adoptLegacy"));
        assert!(LIBRARY_METHODS
            .iter()
            .all(|method| method.starts_with("library.")));
    }

    #[test]
    fn required_capabilities_follow_the_method_tables() {
        assert_eq!(
            required_capability(ENGINE_PROBE),
            Some(crate::version::capability::ENGINE_V1)
        );
        assert_eq!(
            required_capability(LIBRARY_MATCH_LIST),
            Some(crate::version::capability::CATALOG_V1)
        );
        assert_eq!(
            required_capability(SERVICE_METRICS),
            Some(crate::version::capability::METRICS_V1)
        );
        for lifecycle in [
            SERVICE_HELLO,
            SERVICE_HEALTH,
            SERVICE_PING,
            SERVICE_SHUTDOWN,
        ] {
            assert_eq!(required_capability(lifecycle), None, "{lifecycle}");
        }
        assert_eq!(required_capability("engine.start.doesNotExist"), None);
    }
}
