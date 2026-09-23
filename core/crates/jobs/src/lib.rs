//! The long-running job model.
//!
//! Mobile operating systems suspend backgrounded applications, and analysing a
//! 30–60 minute recording outlives a foreground session. A single long-running
//! function call would be lost on suspension, with no progress and no way to
//! cancel it. Everything here exists to avoid that:
//!
//! * a job has a stable identifier and an explicit lifecycle;
//! * progress is stage-labelled and never decreases within a stage;
//! * cancellation is cooperative and leaves partial artifacts marked non-final;
//! * completed stages are checkpointed into the match directory, so an
//!   interrupted job resumes instead of restarting;
//! * at most one resource-intensive job runs at a time.

#![forbid(unsafe_code)]

mod checkpoint;
mod id;
mod registry;
mod runner;
mod session;
mod state;

pub use checkpoint::{CheckpointStore, JobCheckpoint};
pub use id::JobId;
pub use registry::{JobLease, JobRegistry};
pub use runner::{execute, mark_artifacts_non_final, JobPlan, JobRun};
pub use session::{JobContext, JobSession};
pub use state::{JobProgress, JobState, JobStatus};
