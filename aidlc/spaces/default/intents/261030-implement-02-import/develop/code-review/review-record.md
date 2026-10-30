# Review Record — Import and Media Preparation (Feature 2)

Status: Develop / Code Review
Intent: `261030-implement-02-import`
Consumes: `../code-generation/source-changes.md`,
`../task-planning/implementation-plan.md`
Scope reviewed: `d33d123..4343663` (commits `e756052`, `4cb33db`, `c603d3c`,
`7ca126a`, `62a57c3`, `4343663`), branch `261030-implement-02-import`.

## 1. Method

Multi-agent review per implementation plan §4: six pipeline reviewers (U1,
U2, U3, U4, U5-docs, cross-cutting invariants) plus a dedicated
`security-agent` over the whole range — 24 agents total. Every filed finding
was independently verified by a refuter agent reading the committed source
(default: not-real unless the evidence holds). Known baseline issues (4
`prefer_const_constructors` infos; red `analysis_screen_test.dart` /
`library_screen_test.dart`) and missing-test complaints (waived by the
working agreement) were excluded by instruction and by verification.

## 2. Verdict

**Approve with fixes.** No blocking findings. 3 minor + 4 nit confirmed
(after dedup); fixes are queued for the Refactoring stage. The security lens
returned zero findings: offline/custody/socket-hardening/licensing/no-Rust
guardrails intact, and the AF_UNIX `setOption` removal does not regress the
peer-UID or permission model.

## 3. Confirmed findings (deduplicated)

| ID | Sev | Location | Finding | Fix (queued for Refactoring) |
| --- | --- | --- | --- | --- |
| F1 | minor | `recording_store.dart:164` (U1 + cross-cutting) | The terminal `onProgress(1.0)` is suppressed on normal large imports: the rounded percent reaches 100 at fraction ≈ 0.995 (any file > ~12.8 MiB with 64 KiB chunks), sets `lastPercent = 100`, and the post-flush `1.0` is skipped — contradicting the new dartdoc/API-contract/DD-1 promise "finishing at `1.0`". UI label still reads 100% (ScProgressJob re-rounds), so impact is contractual, not visual. | Gate the in-loop emission at `percent > lastPercent && percent < 100` and emit the post-flush `onProgress(1.0)` unconditionally when a callback exists; cap stays ≤ 101 (1 + 99 + 1). Update spec §2.1 step 5 wording and DD-1 consequence to match. |
| F2 | nit | dartdoc in `match_library.dart:32`, `recording_store.dart:57`, `match_repository.dart:100` | "starting at `0.0` and finishing at `1.0`" over-promises: cancelled/failed paths stop early with no final value, and `1.0` means bytes flushed — not renamed, cataloged, or saved. | Reword the three doc comments: 0.0 before first chunk, updates as the copy advances, 1.0 once flushed; may stop early on cancel/failure; 1.0 ≠ match saved. Note the fake intentionally ignores the callback. |
| F3 | nit | `import_controller.dart:25` | The widened `ImportState` constructor line is 82 columns — not `dart format` clean. | Run `dart format` on the file (or hand-break the parameter list); no behavior change. |
| F4 | nit | `artifact_rows.dart:44-45` (U4 + cross-cutting) | Rewritten row doc comment still says size sits "beneath"; the size renders trailing on the numbered row, only the path is beneath. | Reword: kind, state badge, and trailing size on the numbered row; path beneath. |
| F5 | minor | BRD-02 §9 rows BR-8 and BR-11 (lines ~308, ~310) | §9 still cites `analysis_screen_test.dart` as verification while the new §7 row records that file as red at baseline and not regression evidence — internally inconsistent. | Qualify both verification cells with the red-at-baseline caveat pointing at §7 (or drop the file from the column). |
| F6 | nit | BRD-00 revision row (~line 511) and the identical BRD-02 §10 row | "status and evidence cells only" understates the revision: explanation cells in 02 §4/§5 were also edited (which spec §2.8 sanctions). | Record as "status, evidence, and explanation cells only; no Must acceptance text changed" in both docs. |
| F7 | minor | `analysis_providers.dart:114` + engine boundary `core/adapters/api/src/convert.rs:360-364` (cross-cutting) | The partition derives from client state (`ArtifactStateDto.missing`) while the engine derives `missingKinds`/`notRebuildableKinds` from file absence; a `NonFinal` entry whose file is absent maps to `nonFinal` (shows PARTIAL) and is excluded from the rebuild count even though `regenerate_missing` would rebuild it. **Pre-existing at baseline** (the old button used the same `missing` getter); U3 inherited it per the approved API contract §2.4. | Decision required at the gate: (a) record as a follow-up for the engine track (map any absent-path manifest entry to Missing in `ArtifactManifestDto::from_manifest`), (b) client-side rebase onto `manifest.missingKinds` now (deviates from approved contract §2.4), or (c) engine fix now (scope expansion into `core/`). |

## 4. Rejected findings (with reason)

| Filed by | Finding | Why rejected (verifier evidence) |
| --- | --- | --- |
| U1 | `remove(matchId)` inside a catch can itself throw and mask the original error | Mechanically accurate but pre-existing baseline shape; the change did not introduce or worsen it; no defect established in the committed diff |
| U2 | `importFraction` passed unconditionally to StudioShell | Filed as "observation, no change required"; rendering is gated by `importRunning` — no defect |
| U3 | Partition inherits state-derived `missing` vs engine file-absence | Duplicate of F7 (filed independently; confirmed there) |
| U3 | 81-column list-comprehension line | Pure formatting preference; repo does not enforce `dart format` on this file's baseline |
| U4 | Badge icon 12 px (`space3`) vs ScPipelineRow's 16 px (`space4`) | Accurate observation, aesthetic preference with no binding DS requirement; badge is a denser local vocabulary |
| U5 | "design pipeline row" claim stale because `_ArtifactRow` no longer uses `ScPipelineRow` | In BRD language the phrase names the DESIGN.md pattern, not the widget class; the row still realizes the pattern |
| U5 | §7 calls `62a57c3` "HEAD" and commit-list phrasing | Document front matter fixes the reading baseline; label is not a git-ref claim; phrasing holds up |
| cross-cutting | `destination.lengthSync()` outside the `on Object` cleanup | `git blame`: pre-existing baseline line, untouched by this change |

## 5. Positives (reviewers teach, not just gate)

- U1: cancel check ordering, clamp-against-stale-probe-size, exact catch
  ordering preserving `_describe`/`isOutOfSpace` mapping, and interface
  parity across all three implementors were all called out as sound.
- U2: the `identical(_token, token)` + phase guard and the unchanged `finally`
  reset correctly prevent stale fractions and cross-import leakage.
- U3: getters match the approved contract verbatim; button logic switched
  consistently with no leftover `state.missing` use; note placement covers
  the "nothing rebuildable but something missing" case.
- U4: metric-by-metric layout parity with the replaced row; word+icon+colour
  always together; shared vocabulary untouched.
- U5: Must acceptance text verifiably untouched; deferred items preserved.
- Security: zero findings across the whole range.

## 6. Disposition

F1–F6 are queued for the Refactoring stage (all mechanical, in-scope, no
contract change beyond aligning spec/DD wording with the F1 fix). F7 needs a
direction decision at the approval gate (recommendation: (a) record as an
engine-track follow-up — the divergence predates this intent and both
in-change fixes have scope costs).
