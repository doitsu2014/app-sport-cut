# highlight-export Specification

## Purpose
Turning the clips a user chose into a finished highlight video: an explicit edit
decision list, a renderer that applies it, a burned-in scoreboard and title card,
background music mixed under the match audio, and a finished file the user can
take out of the application.
## Requirements
### Requirement: Edit decision list
The engine SHALL render a highlight video from an explicit edit decision list that describes the ordered clips, their source time ranges, their padding, the overlay image to composite over each clip, and the export's audio and title settings, and SHALL NOT read the editing catalog itself.

#### Scenario: Edit list describes the reel
- **WHEN** an export is requested for a match
- **THEN** the request carries the ordered clips with source start and end timestamps, the padding to apply around each clip, and the overlay image to composite over each clip

#### Scenario: Edit list independent of renderer
- **WHEN** the same edit decision list is rendered by a different backend
- **THEN** the resulting reel contains the same clips in the same order with the same overlays

#### Scenario: Empty reel rejected
- **WHEN** an export is requested with no clips
- **THEN** the engine rejects the request with an explicit reason
- **AND** no output file is produced

#### Scenario: Clip outside the recording rejected
- **WHEN** a clip's time range falls outside the source recording
- **THEN** the engine rejects the request naming the offending clip

### Requirement: Rendering a highlight video
The engine SHALL render the edit decision list to a single video file whose clips appear in the requested order with the requested trims and padding applied, and SHALL leave the original recording unmodified.

#### Scenario: Reel rendered
- **WHEN** the engine renders a valid edit decision list
- **THEN** a single playable video file is written containing every clip in the requested order
- **AND** each clip begins and ends at its trimmed boundaries

#### Scenario: Padding applied
- **WHEN** a clip requests lead-in or lead-out padding
- **THEN** the rendered clip includes that much source material before and after the clip
- **AND** padding is clamped to the bounds of the recording

#### Scenario: Original recording unmodified
- **WHEN** rendering completes
- **THEN** the source recording remains byte-for-byte unchanged

#### Scenario: Match audio preserved
- **WHEN** the source recording has an audio track and the export requests match audio
- **THEN** each rendered clip carries the source audio for its time range

#### Scenario: Source without audio
- **WHEN** the source recording has no audio track
- **THEN** the render completes with a video-only or music-only result rather than failing

### Requirement: Score overlay and title card
The application SHALL render the confirmed score and any title card as images, and the engine SHALL burn them into the rendered video, showing the score as it stood at each clip's position in the match.

#### Scenario: Score overlay burned in
- **WHEN** a clip is rendered and the export supplies the overlay the application drew for that clip's position
- **THEN** the rendered clip shows the team names and that score over the video
- **AND** the overlay is part of the encoded video rather than external data

#### Scenario: Score does not change mid-clip
- **WHEN** a clip is rendered from a match where the score advanced at rallies outside the clip
- **THEN** the clip shows the score as it stood at that clip's own position in the match

#### Scenario: Title card prepended
- **WHEN** the export requests a title card
- **THEN** the rendered reel begins with the card the application drew
- **AND** the first highlight clip follows it

#### Scenario: Overlay wording is user-supplied
- **WHEN** the user has not supplied team names
- **THEN** the overlay omits them rather than inventing a label

#### Scenario: Missing overlay reported
- **WHEN** an export names an overlay or title image that is not readable
- **THEN** the export fails before rendering, naming the file
- **AND** no partial file is produced

### Requirement: Background music mix
The application SHALL let the user choose an audio file from device storage as background music for the reel, and the engine SHALL mix it under the match audio.

#### Scenario: Music chosen from device storage
- **WHEN** the user selects an audio file from device storage
- **THEN** that file is recorded as the export's music
- **AND** its path is stored with the match's export settings

#### Scenario: Music mixed under match audio
- **WHEN** an export with music and match audio is rendered
- **THEN** the match audio is audible and the music is mixed below it

#### Scenario: Music shorter than the reel
- **WHEN** the chosen music is shorter than the rendered reel
- **THEN** the music is extended or faded to cover the reel rather than ending abruptly

#### Scenario: Unreadable music reported
- **WHEN** the chosen music file cannot be read or decoded
- **THEN** the export reports that as an explicit failure naming the file
- **AND** it does not silently render without music

#### Scenario: No music selected
- **WHEN** the user has not chosen music
- **THEN** the export renders with match audio only

### Requirement: Export completion and destination
The engine SHALL record a completed export as a derived artifact of the match and report its location, and the application SHALL let the user take the finished video out of the application.

#### Scenario: Export artifact recorded
- **WHEN** an export completes
- **THEN** the rendered file is recorded in the match manifest as an exported video artifact with its path and size

#### Scenario: Finished video handed to the user
- **WHEN** an export completes
- **THEN** the application offers the user a way to save or share the finished video

#### Scenario: Cancelled export
- **WHEN** an export is cancelled before it completes
- **THEN** no partial output is presented as a finished video
- **AND** the match is not reported as having an export

#### Scenario: Export removed with the match
- **WHEN** a user deletes a match and chooses to delete its derived artifacts
- **THEN** the exported videos are removed with them

#### Scenario: Export is repeatable
- **WHEN** the user changes the reel and exports again
- **THEN** a new render is produced from the current edit decision list
