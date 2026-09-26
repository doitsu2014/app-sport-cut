# court-calibration Specification

## Purpose
User-marked court calibration: four corners, the court plane and homography, orientation and the net, projected outline, persistence, editing, and offline operation.

## Requirements

### Requirement: Marking the court corners

The application SHALL let the user mark the court by placing four corner points on the recording, SHALL capture the marked position in the frame as the user sees it rather than in the source file's stored pixels, and SHALL NOT record a calibration from fewer than four points.

#### Scenario: Four corners captured
- **WHEN** the user places four court corners on a recording
- **THEN** the application records a calibration for that match with those four positions
- **AND** the calibration is marked complete

#### Scenario: Marked position independent of rotation and resolution
- **WHEN** a recording whose container carries a rotation tag is calibrated
- **THEN** the stored corner positions describe the frame as the user saw it
- **AND** the positions remain valid when the same frame is shown at a different size

#### Scenario: Marked position independent of the preview layout
- **WHEN** the recording is displayed inside a screen whose aspect ratio differs from the recording's
- **THEN** each corner appears where the user placed it while the preview is shown and after it is redisplayed

#### Scenario: Incomplete calibration not saved
- **WHEN** fewer than four corners have been placed
- **THEN** no calibration is recorded for the match

#### Scenario: Positions outside the frame rejected
- **WHEN** a corner position falls outside the displayed frame
- **THEN** the application rejects it rather than storing a position the frame cannot contain

### Requirement: Court plane and homography

The engine SHALL derive, from a complete calibration, a projective mapping between normalized image coordinates and a normalized court plane, SHALL provide the mapping in both directions, and SHALL reject a calibration that cannot define one.

#### Scenario: Mapping produced for a valid calibration
- **WHEN** the engine is given a complete calibration whose four corners are distinct
- **THEN** it returns a mapping from image coordinates to court coordinates and a mapping from court coordinates back to image coordinates

#### Scenario: Mapping round-trips
- **WHEN** an image point is mapped into court coordinates and back
- **THEN** the returned point is the original point within a small tolerance

#### Scenario: Degenerate calibration rejected
- **WHEN** the four corners are collinear, duplicated, or otherwise cannot define a quadrilateral
- **THEN** the engine reports an explicit error naming the problem
- **AND** it does not return a mapping

### Requirement: Court orientation and the net

The calibration SHALL record which way the court runs relative to the camera, and the engine SHALL determine the side a court position belongs to from which half of the net it falls in, rather than from its position in the image.

#### Scenario: Court orientation recorded
- **WHEN** a calibration is recorded
- **THEN** it states whether the court runs away from the camera or across the view
- **AND** that choice determines where the net falls on the court plane

#### Scenario: Position assigned to a side
- **WHEN** the engine is asked which side a court position belongs to
- **THEN** it answers with the half of the net the position falls in
- **AND** the answer does not depend on where in the image the camera was standing

#### Scenario: Side determined for a player position
- **WHEN** a position on the court is reported by a later analysis stage
- **THEN** the engine assigns it a side using the recorded calibration
- **AND** no position is assigned a side when the match has no calibration

### Requirement: Projected court outline

The engine SHALL project the calibrated court back into image coordinates so the application can draw it over the recording, and SHALL include the net so the user can see where the two sides divide.

#### Scenario: Outline available for verification
- **WHEN** a complete calibration is recorded for a match
- **THEN** the engine returns the court outline and the net in image coordinates
- **AND** the application draws them over the recording the user calibrated

#### Scenario: Outline follows an edited corner
- **WHEN** a corner of a recorded calibration is moved
- **THEN** the outline the engine returns moves with it

### Requirement: Calibration stored with the match

The calibration SHALL be recorded as part of the match, SHALL remain available after the application restarts, and SHALL remain available when the match's derived artifacts have been deleted.

#### Scenario: Calibration survives a restart
- **WHEN** a calibration is recorded and the application is restarted
- **THEN** the match still reports its calibration

#### Scenario: Calibration survives deleted artifacts
- **WHEN** a match's derived artifacts are deleted and later rebuilt
- **THEN** the calibration is restored without the user marking the court again

#### Scenario: No calibration invented
- **WHEN** a match has never been calibrated
- **THEN** the application reports that no calibration exists
- **AND** it makes no claim about the court, its sides, or the net for that match

#### Scenario: Engine writes the calibration into the match directory
- **WHEN** a calibration is recorded for a match
- **THEN** the engine writes it into that match's artifact directory and records it in the manifest

### Requirement: Editing a calibration

The application SHALL let the user change a recorded calibration, and a changed calibration SHALL invalidate analysis artifacts that were computed from the previous one instead of leaving them in place as though they still applied.

#### Scenario: Edited calibration replaces the stored one
- **WHEN** the user moves a corner of a recorded calibration and saves it
- **THEN** the stored calibration holds the new positions
- **AND** no other match's calibration changes

#### Scenario: Artifacts from the previous court invalidated
- **WHEN** a saved calibration differs from the one it replaces
- **THEN** analysis artifacts derived from the previous calibration are invalidated
- **AND** they are not presented as results for the new court

#### Scenario: Unchanged calibration discards nothing
- **WHEN** the user opens the calibration and saves it without changing any position
- **THEN** no artifact is invalidated

### Requirement: Calibration is user input, not reproducible output

The engine SHALL treat a calibration as input supplied by the user, and SHALL NOT report a missing calibration as repaired by any rebuild operation.

#### Scenario: Missing calibration reported as needing the user
- **WHEN** a rebuild is requested for a match whose calibration artifact is missing
- **THEN** the engine reports that the calibration cannot be rebuilt
- **AND** it does not report the calibration as restored

#### Scenario: Rebuild completes the artifacts it can reproduce
- **WHEN** a rebuild is requested for a match whose proxy, audio, or frames are missing
- **THEN** those artifacts are rebuilt
- **AND** the outcome distinguishes them from any artifact that could not be rebuilt

### Requirement: Calibration works offline

Calibration SHALL be captured, stored, edited, and projected using local resources only, and MUST NOT require network access.

#### Scenario: Calibration performed without network access
- **WHEN** the user calibrates a match while network access is unavailable
- **THEN** marking, saving, editing, and viewing the projected court all work normally

#### Scenario: No recording data leaves the device
- **WHEN** a match is calibrated
- **THEN** no frame, corner position, or recording data is transferred to any external service
