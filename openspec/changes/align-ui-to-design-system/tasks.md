## 1. Studio rail

- [x] 1.1 Add a trailing primary check glyph to done stages in `_FeatureItem`
- [x] 1.2 Use `secondaryContainer` for the selected video row in `_VideoRail`
- [x] 1.3 Reveal the video-row delete action on hover instead of always

## 2. Score screen

- [x] 2.1 Colour the serving side's score numeral `primary` in `_Side`
- [x] 2.2 Restyle `_WinnerButton` to 44×36, radius 4, with picked = primary border + tint and suggested = dashed border + bullet
- [x] 2.3 Render rally numerals tabular in `_RallyTile`
- [x] 2.4 Colour the kept-in-reel star `primary` in `_RallyTile`

## 3. Prepare analysis

- [x] 3.1 Replace `_ArtifactTile` rows with a `DataTable` (kind · path · state · size)
- [x] 3.2 Render each artifact state as a chip (ready / partial / missing)

## 4. Player analysis

- [x] 4.1 Colour-code the legend words with darkened track colours
- [x] 4.2 Add a coverage chip strip (coverage, gaps, timecode)

## 5. Calibration

- [x] 5.1 Add a "Projected net" chip over the projected net line
- [x] 5.2 Add an armed drag state to corner handles (lighten + 3px ring)

## 6. Highlights and export

- [x] 6.1 Render clip numerals tabular in `_ClipTile` and `_LeftOut`
- [x] 6.2 Give the reel-ready card a primary border and primary check icon

## 7. Playback

- [x] 7.1 Keep the missing-recording state's disabled transport and copy aligned with the mockup

## 8. Verify

- [x] 8.1 `flutter analyze` clean and the studio rail, score screen, and analysis table match the mockups
