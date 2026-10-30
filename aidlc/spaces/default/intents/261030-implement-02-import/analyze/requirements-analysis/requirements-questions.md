# Requirements Analysis Questions

Intent: `261030-implement-02-import`
Stage: `requirements-analysis`

Context: An audit of all 35 `FR-IMP` requirements in
`docs/brd/02-import-and-media-preparation.md` against `HEAD` (`d33d123`) confirms
that 33 of 35 requirements are satisfied across `core/` and `app/`. Two Must
requirements are unmet on `HEAD`:
- `FR-IMP-15`: Determinate import progress during the recording copy.
- `FR-IMP-29`: Excluding `notRebuildableKinds` from the rebuild count and
  reporting non-rebuildable missing artifacts with the stage that produces them.

## Q1: How should determinate import progress (`FR-IMP-15`) be computed and displayed?

A. Report a byte fraction `copiedBytes / totalBytes` (`0.0..1.0`) from
   `RecordingStore.takeCustody` via an optional `void Function(double fraction)? onProgress`
   callback (throttled so UI updates are smooth and bounded), store `fraction`
   on `ImportState` (starting at `0.0` once `ImportPhase.importing` begins), and
   pass `import.fraction` into `StudioShell` (`importFraction`) and
   `WorkspaceScreen`'s `ScProgressJob`.
B. Show stage-only progress without counting bytes (e.g. 0% probing, 50%
   copying, 100% saving).
C. Spawn a separate Dart isolate for the file copy and stream progress over a
   `ReceivePort`.
X. Other (describe)

[Answer]: A. Report a byte fraction `copiedBytes / totalBytes` (`0.0..1.0`) from
`RecordingStore.takeCustody` via an optional `void Function(double fraction)? onProgress`
callback (throttled so UI updates are smooth and bounded), store `fraction` on
`ImportState` (starting at `0.0` once `ImportPhase.importing` begins), and pass
`import.fraction` into `StudioShell` (`importFraction`) and `WorkspaceScreen`'s
`ScProgressJob`.

## Q2: How should non-rebuildable missing artifacts (`FR-IMP-29`) be presented in `AnalysisPanel`?

A. Separate `AnalysisState.missing` into `rebuildableMissing` (missing artifacts
   whose `kind` is not in `manifest.notRebuildableKinds`) and
   `notRebuildableMissing` (missing artifacts whose `kind` is in
   `manifest.notRebuildableKinds`). Use `rebuildableMissing` for the "Rebuild N
   missing file(s)" button count and enabled state, and when
   `notRebuildableMissing` is non-empty, show a descriptive note naming each
   non-rebuildable artifact and the studio stage that produces it (`calibration`
   → Mark court, `tracks` → Player analysis, `rally_suggestions` → Review &
   score, `export` → Export).
B. Hide non-rebuildable artifacts from the `AnalysisPanel` altogether.
C. Keep counting all missing artifacts in the Rebuild button, and only show a
   toast after rebuild completes.
X. Other (describe)

[Answer]: A. Separate `AnalysisState.missing` into `rebuildableMissing` (missing
artifacts whose `kind` is not in `manifest.notRebuildableKinds`) and
`notRebuildableMissing` (missing artifacts whose `kind` is in
`manifest.notRebuildableKinds`). Use `rebuildableMissing` for the "Rebuild N
missing file(s)" button count and enabled state, and when `notRebuildableMissing`
is non-empty, show a descriptive note naming each non-rebuildable artifact and
the studio stage that produces it (`calibration` → Mark court, `tracks` → Player
analysis, `rally_suggestions` → Review & score, `export` → Export).

## Q3: How should artifact states (`FR-IMP-30`) be rendered in `ArtifactRows`?

A. Keep `ArtifactRows` on `ScPipelineRow`, and ensure that `ArtifactStateDto`
   maps to explicit status labels (`READY` for `final_`, `PARTIAL` for
   `nonFinal`, `MISSING` for `missing`) or that `ScPipelineRow` / `ArtifactRows`
   renders the state label alongside the size and path so `FR-IMP-30` and
   `analysis_screen_test.dart` both stay coherent.
B. Replace `ArtifactRows` with a Material `DataTable`.
X. Other (describe)

[Answer]: A. Keep `ArtifactRows` on `ScPipelineRow`, and ensure that
`ArtifactStateDto` maps to explicit status labels (`READY` for `final_`,
`PARTIAL` for `nonFinal`, `MISSING` for `missing`) or that `ScPipelineRow` /
`ArtifactRows` renders the state label alongside the size and path so
`FR-IMP-30` and `analysis_screen_test.dart` both stay coherent.

## Contradiction analysis

- Q1-A satisfies `FR-IMP-15` ("The import reports a fraction of bytes copied
  with a stage label and a percentage, and never shows an indeterminate bar for
  more than three seconds without a stage label") and `NFR-2` ("progress updates
  at least once per second") without changing the `RecordingStore` custody
  invariants (`FR-IMP-08` to `FR-IMP-11`).
- Q2-A satisfies `FR-IMP-28` and `FR-IMP-29` ("Artifacts the pipeline cannot
  produce, such as a missing calibration, tracks, or export, are reported as
  still missing with the stage that produces them, and are not counted as
  repaired") using `ArtifactManifestDto.notRebuildableKinds` already populated
  by the Rust engine.
- Q3-A preserves the studio design contract (`DESIGN.md` §6, §10) while meeting
  `FR-IMP-30`.
- No open contradictions.
