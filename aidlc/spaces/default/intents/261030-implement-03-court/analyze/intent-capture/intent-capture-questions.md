# Intent Capture Questions

Intent: `261030-implement-03-court`
Request: implement BRD feature 3 (Court Calibration, area `CAL`).
Mode: yolo (`aidlc/config.json`) — recommended answers auto-selected and
recorded below.

Context: a HEAD audit of `docs/brd/03-court-calibration.md` covered all 24
`FR-CAL` requirements, every §5 design-contract row, the §4 state rows, all six
`NFR-CAL` requirements, and the §7 evidence rows (62 ledger entries, each
adversarially re-verified). The functional core is largely shipped: corner
marking, clamping, save/update, validation-by-name, track invalidation, and
catalog persistence all hold. The central defect is that the engine's returned
projection is never drawn. `CalibrationOverlayHost` passes only the corners to
`ScCalibrationOverlay`; the component derives a net from the midpoints of
corners 0–3 and 1–2, draws no court outline, ignores orientation, paints a net
on an uncalibrated match that was never projected, and leaves the stale net on
screen after an engine rejection. The BRD's own design-gap list is stale: the
40 px amber handles, solid net, raw colours, and floating `PROJECTED NET` chip
it records are already fixed. The genuinely open design work is the instruction
surface, the overlay bed/scrim, motion and the ease curve, and contrast over
footage. Two named screen tests throw at HEAD because they look up
`FilledButton` while the panel renders `ScButton`.

## Q1: What does "implement feature 3" cover?

A. Audit all 24 `FR-CAL` requirements, every §5 design row, and the §7 evidence
   rows against HEAD; implement the verified gaps in `app/` and the design
   components; reconcile BRD 03 and BRD 00 with HEAD.
B. Fix only the §5 design-contract rows and leave the functional projection
   defect alone.
C. Re-implement the calibration feature end to end.
X. Other (describe)

[Answer]: A. Audit all 24 `FR-CAL` requirements, every §5 design row, and the
§7 evidence rows against HEAD; implement the verified gaps in `app/` and the
design components; reconcile BRD 03 and BRD 00 with HEAD.

## Q2: Where does calibration ownership land in this intent?

A. Keep the current client-owned v5 catalog and the existing service transport
   for the calibration artifact; defer the ADR-0001 Phase 3–4 service-owned
   catalog and `library.calibration.save/get` composite to the migration.
B. Move calibration storage, custody, and the catalog row into the Rust service
   as part of this intent.
X. Other (describe)

[Answer]: A. Keep the current client-owned v5 catalog and the existing service
transport for the calibration artifact; defer the ADR-0001 Phase 3–4
service-owned catalog and `library.calibration.save/get` composite to the
migration.

## Q3: How does this intent treat the release-service match-path defect?

A. Record it as a known limitation and a follow-up under ADR-0001 Phase 3/6:
   the client sends `matchDir` as a development affordance, and a release
   service rejects it, so calibration (and every match-scoped call) works only
   under the development transport. Do not change custody in this intent.
B. Fix match-path resolution in this intent by making the release service
   resolve matches from a service-owned state root the client does not own.
X. Other (describe)

[Answer]: A. Record it as a known limitation and a follow-up under ADR-0001
Phase 3/6; do not change custody in this intent.

## Q4: Test posture?

A. Implementation first per the project working agreement (`CLAUDE.md`); leave
   the two stale `FilledButton` lookups untouched and record them as a known
   acceptance-evidence gap; add no new tests.
B. Repair the two existing screen-test assertions (`FilledButton` → `ScButton`)
   so the feature's named evidence runs, without adding new cases.
C. Add widget tests for the design contract (24/44 handles, dashed net,
   accent-on-drag, bed/scrim, motion).
X. Other (describe)

[Answer]: A. Implementation first per the project working agreement
(`CLAUDE.md`); leave the two stale `FilledButton` lookups untouched and record
them as a known acceptance-evidence gap; add no new tests.

## Q5: Gate autonomy for the stages in this intent?

A. Auto-approve gates (`aidlc/config.json` sets `mode: yolo`).
B. Stop for manual approval at every stage.
X. Other (describe)

[Answer]: A. Auto-approve gates (`aidlc/config.json` sets `mode: yolo`).

## Contradiction analysis

- Q1-A versus Q2-A: consistent. The implementation stays inside the
  client-owned v5 catalog and the existing artifact transport; no ownership
  change is implied.
- Q1-A versus Q3-A: consistent. The release-service path is a migration-phase
  limitation, recorded and deferred with the same ADR-0001 scope Q2 already
  defers.
- Q1-A versus Q4-A: consistent with `CLAUDE.md`. The two failing lookups are a
  pre-existing test defect, not one this change breaks at compile time, so they
  are recorded rather than repaired absent an explicit user request.
- Q2-A versus Q3-A: consistent. Both defer the service catalog/custody, and Q3
  adds no package or durable client state.
- No open contradictions.
