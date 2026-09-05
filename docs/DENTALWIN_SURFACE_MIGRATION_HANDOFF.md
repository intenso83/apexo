# DentalWin surface migration: continuity and handoff

Date: 2026-09-04
Last planning reconciliation: 2026-09-05
Status: Phase 1 implementation is in progress. The protected-staging, immutable-snapshot, and layered-rendering slice was completed and verified on 2026-09-05; real-data import remains disabled.

## Task provenance

- Research task: **Analyze odontogram surface splitting**, ID `01a06e11-bb84-7473-86bc-60c3360e1272`, host `local`.
- Main development task designated by the user: **Explore Apexo fork changes**, ID `01a034de-9127-7ff1-97d1-92bbb6ce59c1`, host `local`.
- Shared workspace: `C:\Users\evris\Documents\ChatGPT\Apexo fork`.
- User-supplied source: `C:\Users\evris\Downloads\dontia_images.zip`.
- Local reference: `C:\Users\evris\Documents\ChatGPT\Apexo fork\DentalWin_reference\DentalWin`.
- Original analysis artifact: `C:\Users\evris\.codex\visualizations\2026\09\04\01a06e11-bb84-7473-86bc-60c3360e1272\DentalWin-surface-analysis.md`. Its complete text is preserved below.

This note was created at the user's request to save the work and make it traceable from the main development task. The original research task changed documentation only. On 2026-09-05 the user explicitly authorized implementation after creating and pushing recovery tag `milestone/pre-dentalwin-surface-migration-2026-09-05` at commit `60940cf`.

## User intent and decision state

The user first requested a deep comparison of the tooth pieces with the existing odontogram and explicitly said not to make changes. Follow-up discussion established interest in replicating actual DentalWin treatments, their selected surfaces, and selectable colors. On 2026-09-05, after the protected Git/GitHub recovery milestone was created, the user authorized implementation. The first conservative slice now preserves the verified source facts through staging and Apexo snapshots and supports independent overlay layers; projection creation and real-data import remain separate gated work.

## Planning reconciliation and decision register

This section is the current planning source of truth for DentalWin surface migration. It reconciles the verified analysis below with the present Apexo odontogram, the migration blueprint, and the completed five-patient treatment-history pilot. Update this section whenever a design or migration decision changes.

### Authority and superseded assumptions

- The statements in `docs/DENTALWIN_MIGRATION_BLUEPRINT.md` sections 7.5-7.7 and `docs/ODONTOGRAM_THERAPY_FOUNDATION.md` that reliable historical surface data is unavailable are superseded. The dedicated `odontogrammata` and `CustomerToothState` tables are still empty, and `mdft1`/`mdft2` are still blank, but the verified work-row field `LOGARIASMOIB` contains the actual saved surface codes used by the DentalWin 2D chart.
- Do not infer a surface from a procedure name or current catalogue default when an original clinical work row is available. Row-level values take precedence; catalogue values are defaults for new work and evidence for review only.
- The verified chart roles of the three work tables are now part of planning: `WorksPelatiU` is the initial-condition chart source, `WorksPelatiD` is the alternative-treatment-plan chart source, and `WorksPelati` is the performed-work chart source. This establishes their chart role, but it does not yet prove every status transition, cancellation flag, or plan-to-completion relationship.
- The existing Phase 5 `treatment_history` pilot remains valid as a read-only history import. It is incomplete for chart fidelity and must not be deleted, rewritten, or independently recharged when odontogram projections are added later.

### Target odontogram data decisions

- Keep each clinical work row as an independent, appendable event. Multiple fillings or other restorations on the same tooth must remain separately addressable and separately drawable.
- Retain the existing semantic `surfaces` list for compatibility. Add a compact `cervicalSurfaces` subset, limited to `facial` and `oral`, so cervical location is explicit without turning it into a treatment name or losing unusual legacy combinations.
- Normalize verified DentalWin surface digits as follows:

  | DentalWin code | Apexo semantic surface | Cervical subset |
  |---|---|---|
  | `1` | `distal` | none |
  | `2` | `occlusalIncisal` | none |
  | `4` | `mesial` | none |
  | `5` | `facial` | none |
  | `6` | `oral` | none |
  | `7` | `facial` | `facial` |
  | `8` | `oral` | `oral` |

- Preserve the original surface string alongside normalized values in migration provenance. Reject repeated digits and retain unknown, mixed, or malformed codes for review rather than silently normalizing them.
- Add an immutable per-event drawing snapshot containing the normalized drawing behavior, the original behavior value from `LOGARIASMOIA`, and the original packed ARGB color from `OikonomikiID`. The event snapshot, not the live catalogue, controls historical rendering.
- Keep treatment status independent from material color. The chosen/imported treatment color represents the restoration material layer; status must remain visible through a separate outline, pattern, opacity treatment, or badge. Status colors must not overwrite the saved treatment color.
- Add a canonical link from a future odontogram event to its imported `treatment_history` or clinical-event record. The odontogram event is a chart projection of the same source treatment, not a second treatment or a second financial charge.
- Expand tooth validation before importing the two verified primary-tooth filling rows. Permanent and primary dentitions must remain explicitly distinguishable; an invalid or multi-tooth value never becomes a permanent tooth by coercion.

### Procedure-catalogue planning

- Continue using procedure-level `defaultSurfaces`, but populate them from verified `WooksTools.onomaImage` codes when valid.
- Add explicit procedure defaults for drawing behavior (`WooksTools.onomaImage3`) and drawing color (`WooksTools.topa`). These defaults apply to new entries and may help review old rows; they do not replace row-level snapshots.
- Treat drawing behavior as a typed setting separate from the current broad handling mode and overlay kind. In particular, crown and veneer must not share one indistinguishable rendering path: DentalWin crowns use the complete tooth strip, while veneers use the `_o` artwork.
- Preserve unknown drawing modes and catalogue fields as raw migration metadata and put them in a review queue. Name-based overlay inference remains only a compatibility fallback for native Apexo records that predate explicit settings.
- Changing a catalogue surface, behavior, or color later must not repaint historical events.

### Rendering and asset plan

- Replace the current one-marker-per-overlay-kind reduction with a supersession-aware layer list. Exclude cancelled or explicitly superseded events, but do not discard an older independent restoration merely because a newer filling exists on the same tooth.
- Paint DentalWin-derived work in deterministic ascending source order (date, then stable source row ID), so later work appears above earlier work as in DentalWin. Native Apexo events use recorded time and stable event ID as the equivalent order.
- Keep the current neutral `assets/odontogram/v1/` anatomy intact. Introduce the supplied DentalWin-style pieces as a separately versioned restoration-mask package rather than silently replacing the base artwork.
- Preprocess the 92-pixel-wide multi-view strips into aligned, manifest-driven runtime masks. The manifest must record source hash, tooth, view, suffix/meaning, dimensions, offsets, and missing/invalid status. Runtime rendering should use the prepared assets directly to remain lightweight.
- Apply the event's saved color through the prepared alpha mask. DentalWin's observed 80% opacity is the initial fidelity reference, not a final UI decision until side-by-side validation confirms readability in Apexo.
- Define explicit assets/behaviors for complete-tooth crowns and `_o` veneers. `_o` must never be interpreted as occlusal. Missing artwork such as `36_o.png` enters asset review; do not silently substitute the crown image or claim exact fidelity.
- Keep a readable geometric surface selector in the UI. The shaped pieces overlap and are rendering masks, not exclusive pixel hit regions.

### Migration-pipeline revision

Implementation is now authorized. Mapping version `2026-09-05.phase6-surface-snapshot-v1` proceeds in this order:

1. Extend protected staging for catalogue defaults: raw and normalized surface codes, drawing behavior, packed ARGB color, and any verified multi-tooth behavior.
2. Extend protected clinical-work staging for `LOGARIASMOIB`, `LOGARIASMOIA`, `OikonomikiID`, and `LOGARIASMOIC`, retaining both raw and normalized forms.
3. Parse only allow-listed surface digits and validated tooth values. Normalize packed ARGB without changing the original numeric value. Send unknown drawing modes, malformed surface strings, missing assets, and ambiguous tooth/multi-tooth mappings to explicit review reasons.
4. Preserve the verified source-table chart role on every staged row. Do not convert that role into final Apexo status until the remaining DentalWin status fields and lifecycle controls are validated.
5. Upgrade `ConvertTo-DwTreatmentHistoryData` so the canonical history record can retain these chart snapshots. For rows already imported by the five-patient pilot, link by existing provenance and update only under an explicitly approved, idempotent mapping-version policy.
6. Create at most one odontogram projection per source row and mapping version, linked to the canonical history record. A repeat run must report `already_imported` or an approved update; it must not add another treatment, projection, or charge.
7. Keep financial import separate. Surface replay must never create ledger entries from `xreosi`, `pistosi`, totals, or catalogue prices.

Recommended new protected review reasons are:

- `surface_code_invalid`;
- `surface_code_repeated`;
- `drawing_behavior_unknown`;
- `drawing_color_invalid`;
- `odontogram_asset_missing`;
- `primary_tooth_not_supported`;
- `multi_tooth_mapping_ambiguous`;
- `history_projection_link_missing`.

### Required validation gate

Before any larger test import, use synthetic records and then an isolated owner-reviewed sample covering:

- an O, MO, OD, and MOD filling;
- facial and oral cervical restorations (`7` and `8`);
- two independent restorations on one tooth with overlapping pieces;
- crown and veneer behavior, including the missing tooth-36 veneer asset case;
- a valid primary tooth and an ambiguous/multi-tooth source value;
- initial-condition, alternative-plan, and performed-work rows;
- a planned item later completed, without assuming the relationship from matching text alone;
- original ARGB color, 80% blending reference, deterministic layer order, source linkage, and repeat-import idempotency;
- confirmation that no odontogram projection creates or duplicates a financial charge.

The aggregate expectations retained for this gate are 2,572 filling-render rows in `WorksPelati`, of which 2,491 have one valid permanent FDI tooth, 2 have one valid primary FDI tooth, and 79 require tooth-mapping review. `WorksPelatiD` and `WorksPelatiU` remain separate validation populations.

### Decisions still open

- Final typed vocabulary for all DentalWin drawing behaviors beyond the verified filling, crown, and veneer paths.
- Exact mapping of DentalWin status/cancellation fields to Apexo `existing`, `planned`, `completed`, and `cancelled` states.
- Whether the familiar single cervical toggle should be the only native entry control or whether advanced users may set facial/oral cervical location independently. Storage remains capable of preserving both.
- Approved fallback presentation when a valid event has missing artwork. It must stay visible in history and must not be silently drawn as another treatment type.
- Whether migrated chart projections appear in the existing treatment-history timeline, the odontogram timeline, or one unified timeline. The underlying treatment remains canonical and singular in every option.
- Exact visual parity target versus an Apexo-native visual style after the fidelity sample is reviewed.

### Change-control rule

Planning changes must be recorded in this decision register with a date and the evidence or owner decision that caused the change. The 2026-09-05 authorization covers implementation and synthetic/isolated verification. It does not authorize importing into a production PocketBase instance or mutating the original DentalWin databases.

### Implementation log — 2026-09-05

- Created and pushed the protected pre-implementation recovery milestone at `60940cf`.
- Began staging-format v1.1. Valid DentalWin surface digits are normalized without treatment-name inference; repeated or malformed values are retained and sent to review.
- Added explicit chart roles for `WorksPelatiU`, `WorksPelatiD`, and `WorksPelati` while preserving the existing `WorksPelati` stage keys used by the five-patient pilot.
- Began immutable event/catalogue snapshots for cervical location, drawing behavior, packed ARGB material color, and canonical treatment-history linkage.
- Replaced same-kind overlay collapsing with deterministic, supersession-aware layering. Saved material color is independent from the status outline.
- Veneer events are deliberately not rendered with crown artwork while the verified `_o` mask package is absent; they remain visible in event history/counts.
- Static analysis completed without issues. Thirty-five focused Flutter model/overlay/catalogue/history/widget tests and all 91 synthetic, encrypted-staging, read-only Access, and isolated-import migration assertions pass.
- A broad Flutter run completed with 1,864 passing tests. Its five live-backend failures require the optional local PocketBase service and include a shared Hive lock; one existing image golden differs by 2.23% in shader-raster output. The focused odontogram visual and behavior checks are otherwise green, and the golden baseline was not silently replaced.
- No production data import, financial record creation, or DentalWin database write is part of this phase.

## Proposed design

- Extend the current procedure-driven system with drawing behavior, semantic surface presets, cervical location, and a default treatment drawing color.
- Preserve individual treatment surfaces and color on each saved event. Changing a catalog default must not rewrite historical appearances.
- Use the shaped PNG pieces as restoration artwork while retaining semantic clinical records and a readable surface selector. The pieces overlap and are not an exclusive click-region partition.
- Keep clinical status separately identifiable from a user-selected treatment color.
- Preserve multiple independent restorations on one tooth; do not collapse all fillings to one event.
- Import actual stored work-row surfaces, drawing behavior, and color with dates, status, and source provenance. Do not reconstruct history from current catalog defaults when the original row is available.
- Link migration events idempotently to existing imported treatment history and financial records; do not duplicate records or charges.

## Current Apexo gaps observed during analysis

These are observations of a changing shared checkout on 2026-09-04; recheck the current code before implementation.

- `lib/features/odontogram/odontogram_event_model.dart`: supports semantic surfaces, dates, status, catalog snapshots, and migration metadata, but no per-event drawing color or cervical-region field at the time inspected. Tooth validation currently handles permanent FDI teeth.
- `lib/features/odontogram/odontogram_overlay_painter.dart`: marker selection keeps one event per overlay kind on a tooth, and appearance uses built-in kind/name logic rather than the source record's color.
- `lib/features/therapy_catalog/procedure_catalog_model.dart`: existing surface selection settings provide a foundation; group colors are not equivalent to per-procedure and per-event drawing colors.
- `tool/dentalwin_migration/DentalWinTestImport.psm1`: `ConvertTo-DwTreatmentHistoryData` creates treatment-history records without selected surfaces, drawing behavior, or color; the current import does not replay those records into odontogram events.
- The current 256 x 256 per-view assets require alignment work to use the supplied 92-pixel-wide multi-view strips.

Existing docs such as `docs/ODONTOGRAM_THERAPY_FOUNDATION.md`, `docs/DENTALWIN_MIGRATION_BLUEPRINT.md`, and `docs/DENTALWIN_PHASE5_TREATMENT_HISTORY_PILOT.md` should be reconciled during future planning. Any earlier inference that surfaces are unavailable because mdft fields or dedicated chart tables are empty is superseded by the verified save/load mapping below.

## Recommended next validation before projection/import authorization

Use an isolated test dataset to compare an MOD filling, a cervical filling, two independent restorations on one tooth, a crown, a veneer, and a planned treatment later completed. Validate tooth/surfaces/date/status, original color and blending, layer order, source linkage, and repeat-import behavior. The counts below identify candidates, not fully validated imports. Primary teeth, unusual or multi-tooth values, unknown drawing modes, and missing/misnamed asset cases need explicit review. Exact 2D visual fidelity has not been demonstrated in a live side-by-side test. DentalWin Cloud and complete 3D parity are outside the verified scope.

## Evidence retention

The following original audit includes source fingerprints, aggregate counts, code method references, and a public corroborating source. It contains no patient names or patient-level records. Its decompiled-code links point to temporary local analysis files and can expire; the source binary fingerprints and method names remain the reproduction anchors. No proprietary source code or patient database is copied into this documentation file.

---

# DentalWin surface handling: verified analysis

Date: 2026-09-04. Scope: local DentalWin Desktop reference copy, DentalWin.exe file version 22.07.05.1332. Static inspection of selected program classes and aggregate SELECT queries against a temporary copy of dental.mdb. The application was not launched. Project code, source application files, and the source database were not changed.

## Direct findings

- All 291 PNGs in the supplied dontia_images.zip match the local DentalWin reference files byte-for-byte (290 in dontia_images; chart.png in the program root).
- DomiChartControl draws chart.png as base artwork. Its main chart mouse handler selects teeth by chart coordinates, not individual surface-image pixels.
- frmXDomiAddWorkLine provides a separate geometric five-zone selector for filling drawing modes. The selection uses coordinate bounds, not alpha hit testing against the PNGs. Procedure presets initialize the selected zones; clicks toggle them. A color control supplies the treatment color.
- Surface codes: 1 distal, 2 chewing/biting region (occlusal/incisal in this 2D asset system), 4 mesial, 5 facial, 6 lingual/palatal. The independent catalogue examples confirm 24=MO, 12=OD, 124=MOD, 2=O, 6=palatal groove.
- Checking cervical (Αυχενικά) substitutes 7 for selected 5 and 8 for selected 6. It leaves 1, 2, and 4 unchanged. On loading 7/8, the selector converts them back to 5/6 and checks cervical. This is a shared cervical setting within the selection, not independent facial and oral region flags.
- Draw_Emfraxi loads each selected suffix, applies FadeBitmap with opacity 80%, applies ColorScaleFilter from black to the chosen color, and draws at the tooth's chart offset. It skips an empty surface string and skips missing piece files. Pieces are drawn sequentially rather than unioned into one mask.
- Crowns use the complete tooth strip. Draw_Opsi (veneer) uses the _o image. The _o suffix does not mean occlusal. The missing 36_o.png is therefore relevant to that veneer path; no fallback to 36_.png appears in the inspected method.
- The rendering loop draws every work row in its loaded tables. Rows in the main chart paths are loaded in ascending date and ID order; extra/background work is drawn before the current work table. Independent fillings are not reduced to one newest filling. Later layers can cover or blend with earlier layers on overlap.
- Initial condition, alternative treatment plans, and performed work have separate chart modes and source tables: WorksPelatiU, WorksPelatiD, and WorksPelati, respectively, with settings to include other states in the display. These table roles are explicit in the inspected loading paths.

## Storage mapping verified by both save and load code

| Meaning | Procedure catalogue WooksTools | Clinical work row |
|---|---|---|
| Default/selected surface codes | onomaImage | LOGARIASMOIB |
| Drawing behavior | onomaImage3 | LOGARIASMOIA |
| Color, packed ARGB | topa | OikonomikiID |
| Tooth | Procedure requirement and user selection | donti |
| Multi-tooth mapping | Procedure behavior and selection | LOGARIASMOIC |

These are reused legacy field names. In this chart path, onomaImage holds surface codes rather than an image basename, and OikonomikiID supplies drawing color. The empty mdft1/mdft2 fields do not establish an absence of patient surface data.

## Aggregate database verification

Queries exposed only aggregate counts and non-patient catalogue definitions.

| Table | All rows | Nonblank LOGARIASMOIB | Codes matching [1245678]+ | Filling drawing rows with those codes |
|---|---:|---:|---:|---:|
| WorksPelati | 11072 | 2676 | 2651 | 2572 |
| WorksPelatiD | 1997 | 424 | 419 | 402 |
| WorksPelatiU | 749 | 217 | 217 | 217 |

Within the 2572 WorksPelati filling rows: 2491 have a single valid permanent FDI code, 2 have a single valid primary FDI code, and 79 require further tooth-mapping review. None of these 2572 numeric strings repeats a digit. These counts establish available source data, not a completed migration validation or import.

Selected catalogue cross-checks: resin MO -> 24; resin O -> 2; resin OD -> 12; resin MOD -> 124; palatal-groove resin restoration -> 6; resin core buildup -> 12456.

## Implications for Apexo

Keep semantic surface records. Use validated masks for realistic restoration rendering and a separate readable selection control. Cervical location should remain distinguishable from the parent surface. Support multiple independent restorations on a tooth. Revisit the migration mapping using the patient work row's actual stored codes rather than assuming surfaces are absent or deriving them from procedure names. Preserve unknown and exceptional mappings for review. No importer or project changes were made during this analysis.

The local DomiTooth component also has a separate 3D renderer using letter-coded SetSurfaceColors calls. That is a different rendering path; the findings above concern the 2D PNG chart. Current DentalWin Cloud behavior was not verified by these local files.

## Technical evidence locations

The following are temporary analysis outputs generated by decompiling only selected classes, without executing DentalWin:

- Catalogue mapping: [frmXDomiAddWorkLine.cs:2576](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:2576>)
- Procedure preset selection: [frmXDomiAddWorkLine.cs:2696](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:2696>)
- Cervical substitution and selected-code output: [frmXDomiAddWorkLine.cs:2875](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:2875>)
- Geometric click handling: [frmXDomiAddWorkLine.cs:2955](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:2955>)
- Five-zone geometry: [frmXDomiAddWorkLine.cs:3024](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:3024>)
- Procedure-controlled selector visibility: [frmXDomiAddWorkLine.cs:3117](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXDomiAddWorkLine.cs:3117>)
- Chart modes and source fields: [DomiChartControl.cs:5372](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:5372>)
- Work-row drawing loop: [DomiChartControl.cs:6136](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:6136>)
- Chart tooth coordinate lookup: [DomiChartControl.cs:6866](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:6866>)
- Chart tooth selection: [DomiChartControl.cs:7116](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:7116>)
- PNG restoration drawing: [DomiChartControl.cs:7833](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:7833>)
- Crown drawing: [DomiChartControl.cs:8018](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:8018>)
- Veneer drawing: [DomiChartControl.cs:8151](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:8151>)
- Opacity processing: [DomiChartControl.cs:10770](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/DomiChartControl.cs:10770>)
- Clinical row persistence: [ctrDomiClientOdontograma.cs:11993](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/ctrDomiClientOdontograma.cs:11993>)
- Legacy selector Greek labels: [frmXEmfraxiData.cs:985](<C:/Users/evris/AppData/Local/Temp/apexo-dentalwin-analysis-20260904/frmXEmfraxiData.cs:985>)

## Source fingerprints (SHA-256)

- DentalWin.exe: `0895846eb601a9da1add28d9982fd79cf869e8ca0ee7d39f65eb7a3e04b9f87d`
- DomiTooth.dll: `ca63a540acde221a8446f5eafdce7cac32ce837adc87cc8ad4f1653b0ef2a4e2`
- dental.mdb: `22ef719237e18e8933988e4fefe6dacbb9535dc46f97269dbf567d1c41265783`

External corroboration: [official DentalWin odontogram help](https://wiki.domi.gr/dentalwin/οδοντογράμματα/). The help describes tooth selection, treatment recording, and plan-to-performed workflow; it does not document the internal PNG or database mapping.
