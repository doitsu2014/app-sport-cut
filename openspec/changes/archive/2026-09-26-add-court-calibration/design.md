## Context

Wave 2 of the roadmap opens with court calibration because it is the only
feature in that wave with no external gate, and because everything downstream
reads it. The scaffolding is already in place and idle: `sportcut-court` holds
only a doc comment, `ArtifactKind::Calibration` and the `calibration/` directory
exist in the match layout, `matches.court_calibration` exists as a column that is
written and read by nothing, and `/match/calibration` renders a placeholder.

Three properties of the existing engine shape this design.

**Frames come from the proxy, and the manifest records no dimensions.** Frame
sampling reads the reduced-resolution proxy, not the original
(`core/crates/media/src/pipeline.rs`), and `ArtifactEntry` carries a path, a
state, a size, and a timestamp but no width or height. A consumer of a match
directory therefore cannot know what pixel grid a frame is on without opening
it.

**Rotation is applied when the proxy is written.** The proxy is produced by
ffmpeg without `-noautorotate` and is re-probed afterwards, so the proxy and the
frames sampled from it are upright while the original may carry a rotation tag.
The playback widget shows the rotated frame. Any coordinate the user marks is
therefore captured in a space that differs from the original's stored pixels.

**The engine must keep building with no mobile toolchain.** `tools/verify-engine.sh`
runs `cargo clippy --workspace --all-targets` and `cargo test --workspace` over
every workspace member. Whatever this change adds must stay buildable and
testable with Rust and ffmpeg alone — which is one more reason the first court
capability is arithmetic rather than inference.

## Goals / Non-Goals

**Goals:**

- Capture four court corners on a recording and turn them into a court coordinate
  system that later features can consume.
- Answer "which side of the net is this point on" without a metric court model
  and without depending on where the camera was standing.
- Persist the calibration so it survives restarting the app, wiping the artifact
  directory, and editing it later.
- Make the calibration visible to the user as a projected court outline, so the
  user can check and correct it instead of trusting four taps blindly.
- Stop the regeneration path from claiming to rebuild something it cannot.

**Non-Goals:**

- Any person detection, pose estimation, tracking, or player count. The `vision`
  crate is untouched; calibration is what those features will read, not part of
  them.
- Metric accuracy: distance in metres, serve position, and movement speed.
  Those are Wave 3 ranking signals and need a physical court model.
- Automatic court detection. The user marks the corners.
- Court calibration for a moving or hand-held camera. The product's stated
  camera expectation is fixed and stationary.
- Recalibration that tracks a camera slowly drifting. A camera that moves mid
  recording is handled by the user re-calibrating, not by the engine.

## Decisions

### D1: The canonical coordinate space is normalized displayed frame space

Calibration corners are stored as `(x, y)` in the range `[0, 1]²` measured in the
frame as the user sees it, not in the original's stored pixels.

*Alternatives considered.* Absolute pixels in the original would be wrong
whenever the container carries a rotation tag, because the user marks corners on
a rotated view. Absolute pixels in the proxy would pin the calibration to a
proxy resolution that the manifest does not record and that regeneration is free
to change. Normalized coordinates in *stored* pixel space would put the rotation
correction back into every consumer.

Normalized displayed coordinates are the one space in which the preview, the
proxy, and the sampled frames agree without conversion, and they are resolution
independent by construction. The cost is a single implementation rule the client
must honour: the drawing overlay and the video surface must occupy the same box
at the same aspect ratio, so that a tap position divided by the box size is the
normalized coordinate. Letterboxing the video inside a larger overlay box would
break the mapping silently, so the requirement is stated in the spec rather than
left as a comment.

### D2: The court plane is the unit square, and the net sits at the midpoint of the long axis

The homography maps normalized image coordinates to the court's unit square. A
point's side is which half of the net it falls in, expressed in court
coordinates.

*Alternatives considered.* A metric court (13.4 m by 6.1 m) would give distances
immediately but prices in the physical model: the user has to have marked the
doubles sidelines rather than the singles lines, and every consumer inherits an
assumption about which lines were tapped. A single point at the court centre
would be cheap but cannot express the net's orientation under perspective, and
the image-space midpoint of the tapped quad is *not* the projection of the
court's centre.

The unit square costs nothing that Wave 2 needs: locating players, counting them,
and assigning a side are all satisfied by court coordinates without a scale.

### D3: The user states which way the court runs, in one explicit choice

Marking four corners does not say whether the edge nearest the camera is a
baseline or a sideline, and the net falls at the midpoint of the court's *long*
axis either way. So the calibration carries one piece of information besides the
four points: whether the court runs away from the camera or across the view.

*Alternatives considered.* Sorting the tapped points geometrically cannot
resolve it, because a rectangle's corner order is only determined up to
reflection — the reflection is exactly the ambiguity in question. Inferring it
from the quad's proportions does not work either, since a baseline view and a
sideline view are both wider than they are tall in a landscape frame.
Marking the net line as a fifth and sixth point removes the question and pins the
split directly where the user sees it, at the cost of two more taps and a
requirement that the net be visible; that is a better second iteration than a
first one, and the record schema is shaped so it can be added without a rewrite.

The choice is presented in the user's terms — the court stretches away from the
camera, or across it — not as court geometry, because that is the fact the user
can answer without knowing which line is which.

### D4: "Side" is the half of the net; left and right stay presentation labels

The durable quantity is which half of the net a point is in. The score model's
`left` and `right` are a labelling of those two halves and are not re-derived
from the geometry.

*Alternatives considered.* Renaming the score model's sides to something
camera-relative would describe an end-on camera better, but `winner_side` is
already stored as `left` and `right`, is rendered by the export overlay, and is
confirmed by the user one tap at a time. Renaming it costs a catalog migration
and an export change to buy a naming improvement that belongs to a later
usability change, not to this one.

The consequence is recorded rather than hidden: for a recording shot from behind
a baseline, the two halves read to the user as near and far even though the
score screen calls them left and right.

### D5: The catalog holds the calibration; the match directory holds a projection of it

`matches.court_calibration` becomes the source of truth. The engine writes
`calibration/calibration.json` into the match directory as a projection of the
same value, so a headless run can work from the match directory alone.

*Alternatives considered.* Making the manifest the source of truth would put
user-authored data in a directory the app is allowed to delete — the delete flow
offers to remove derived artifacts — so the user's calibration could be destroyed
by a cleanup action that was supposed to be recoverable. Keeping both writable
creates drift: the user re-marks the corners and analysis silently uses the old
ones.

One writer, one direction. The catalog is authored; the artifact is derived from
it by the same operation that saves the calibration, never independently.

### D6: Calibration is not a pipeline stage and is not regenerable

Calibration is an input the user supplies, not output the engine computes, so it
does not join `STAGES`, does not appear in `checkpoints.json`, and is never
reconstructed by regeneration.

Regeneration currently reports every missing artifact kind as repaired while
re-running only the proxy, audio, and frame stages, so recording a calibration
artifact would make it claim to have restored a file it never touched. The
regeneration contract narrows to artifacts the engine can actually rebuild, and
a missing calibration is reported as needing the user.

This is a **breaking** change to a contract rather than to a caller: the analysis
screen offers "rebuild what is gone" and must now distinguish what it can rebuild
from what it cannot.

### D7: The engine returns the homography; the client draws with it

The facade returns both directions of the mapping as 3×3 matrices.

*Alternatives considered.* Having the engine return the projected guide lines
directly would keep the client ignorant of geometry, but fixes what the client
can draw — a player's projected position, added in the tracking feature, would
need another call and another DTO. Re-implementing the homography in Dart would
put the same maths in two languages and two test suites.

Returning both directions avoids writing a matrix inverse in Dart. The client
does not need to draw the net or the court's interior lines from the four tapped
points alone — and cannot, because the image-space midpoint of the quad is not
the projection of the court's midpoint. While the user drags a handle the client
draws only the quad, which four points define for free, and the projected court
comes from the engine. The projected outline is the verification UI: the user
nudges the corners until the drawn lines sit on the painted ones.

### D8: The record holds a list of segments from the start

`calibration/calibration.json` and the catalog value both carry a list of
segments, each with a start time and a set of corners. The first implementation
always writes exactly one segment covering the whole recording.

The list costs nothing now and avoids a schema break later, when a tripod gets
knocked and the user wants to re-calibrate from that moment on. A single-value
record would make that a migration of stored user data.

### D9: Re-calibrating invalidates what was computed from the old court

Saving a changed calibration invalidates derived artifacts that depend on it —
currently `Tracks`, and in Wave 3 the rally records derived from tracking. The
invalidation is recorded against the artifact kinds the manifest knows, using
the existing `forget` primitive, so a stale track set can never be presented as
belonging to the new court.

A calibration identical to the stored one invalidates nothing, so opening the
screen and confirming does not discard analysis.

## Risks / Trade-offs

**Rotation handling is asserted rather than proven.** The design assumes the
proxy and its sampled frames are upright because ffmpeg autorotates by default.
If that assumption is wrong, normalized displayed coordinates would map mirrored
or transposed onto the frames. → Verify with a rotation-tagged fixture before
building the UI, and treat a mismatch as a blocker rather than an edge case.

**Four taps are exactly determined, with no redundancy.** One careless tap skews
the whole plane and nothing in the data reveals it. → The projected court
outline is shown before the calibration is saved, and the user can adjust any
handle; a least-squares fit over extra points is the natural follow-up.

**Perspective error grows with distance.** Near the horizon, a small pixel error
in a corner maps to a large error in court coordinates, so the far half of an
end-on view is the least reliable region — which is also where players are
smallest and least likely to be detected. → Record the limitation; assign a
tracked player by its representative position over a rally rather than
frame-by-frame, which the tracking feature will do.

**Side assignment is weakest exactly at the net.** A player reaching across the
net is genuinely on the other side for a moment, and the point of contact is the
hardest place to locate. → The spec requires side assignment to be a property of
a position over time, not of a single frame, and the failure is visible to the
user rather than silent.

**The catalog and the artifact can disagree if the artifact write fails.** →
The save is ordered so the catalog is written last: a calibration that reached
the catalog has a matching artifact, and a failure leaves the previous
calibration intact rather than a half-saved new one.

**This change makes the engine workspace depend on `sportcut-court`.** → The
crate stays pure arithmetic with no native dependency, so `cargo clippy
--workspace --all-targets` and `cargo test --workspace` keep working on a machine
with no mobile toolchain.

## Migration Plan

No data migration is required. `court_calibration` already exists in the catalog
and is simply unused, so the change is to start reading and writing it: an
existing install keeps every match and each one loads with no calibration.
Artifact directories gain a file and no new directory, because `calibration/` is
already created with every match. Rollback is to stop reading the column: the
stored value becomes inert and no match is lost.

## Open Questions

- Whether marking the net line should replace the explicit "which way does the
  court run" choice in a later change. The record schema does not have to change
  either way; only the capture UI and the validation would.
- Whether a calibration should be required before analysis can run, or optional
  with the analysis proceeding without side information. The user experience
  flow implies it is asked for right after import, but the engine has no reason
  to refuse work without it.
