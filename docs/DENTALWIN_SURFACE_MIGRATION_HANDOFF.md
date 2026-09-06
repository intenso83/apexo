# DentalWin surface migration: continuity and handoff

Date: 2026-09-04
Last planning reconciliation: 2026-09-06
Status: Phase 2 isolated projection review is ready. Protected staging, immutable snapshots, layered rendering, and a five-patient loopback-only odontogram pilot were completed and verified on 2026-09-05; production import remains disabled.

## Task provenance

- Research task: **Analyze odontogram surface splitting**, ID `01a06e11-bb84-7473-86bc-60c3360e1272`, host `local`.
- Main development task designated by the user: **Explore Apexo fork changes**, ID `01a034de-9127-7ff1-97d1-92bbb6ce59c1`, host `local`.
- Shared workspace: `C:\Users\evris\Documents\ChatGPT\Apexo fork`.
- User-supplied source: `C:\Users\evris\Downloads\dontia_images.zip`.
- Local reference: `C:\Users\evris\Documents\ChatGPT\Apexo fork\DentalWin_reference\DentalWin`.
- Original analysis artifact: `C:\Users\evris\.codex\visualizations\2026\09\04\01a06e11-bb84-7473-86bc-60c3360e1272\DentalWin-surface-analysis.md`. Its complete text is preserved below.

This note was created at the user's request to save the work and make it traceable from the main development task. The original research task changed documentation only. On 2026-09-05 the user explicitly authorized implementation after creating and pushing recovery tag `milestone/pre-dentalwin-surface-migration-2026-09-05` at commit `60940cf`.

## User intent and decision state

The user first requested a deep comparison of the tooth pieces with the existing odontogram and explicitly said not to make changes. Follow-up discussion established interest in replicating actual DentalWin treatments, their selected surfaces, and selectable colors. On 2026-09-05, after the protected Git/GitHub recovery milestone was created, the user authorized implementation. The first conservative slice preserves the verified source facts through staging and Apexo snapshots and supports independent overlay layers. The second slice now creates canonical-history-linked projections only in a newly created isolated loopback server for owner review; production import remains a separate gated decision.

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
- Catalogue handling now follows a strict evidence order: an explicit user-selected `handlingMode` or overlay wins, then compatible legacy target fields, then verified structured DentalWin drawing/surface metadata, and only then translated-name/group guessing. This prevents a translation or Greek inflection from discarding stronger source facts.
- For older pilot catalogue records that predate explicit handling fields, `defaultDrawingBehavior=filling` plus a nonempty, valid editable `defaultSurfaces` list resolves to `surfaceBased` when `toothRequired` is not explicitly false. Verified crown and veneer drawing behaviors resolve to the whole-tooth workflow under the same no-explicit-false guard. Missing, malformed, or unknown structured data does not activate this rule; the guarded importer leaves its explicit handling fields unset for review, while the existing name/group classifier remains only a compatibility fallback at runtime.
- New guarded catalogue imports emit `handlingMode=surfaceBased`, `targetScope=tooth`, and `surfaceSelectionMode=optional` for verified fillings with valid presets. Verified crown/veneer records emit the canonical whole-tooth fields. The importer does not update an already-imported record, so a clinician's later explicit catalogue choice remains untouched.
- Surface presets are starting values, not locked clinical findings. The native entry control must initialize the five DentalWin-style zones from the catalogue and allow the clinician to toggle the final surfaces before saving each event.
- A treatment group may be preselected for navigation, but no treatment procedure is selected implicitly. The clinician must make an explicit procedure choice before procedure defaults, surfaces, laboratory pricing, or the Record/Add action become active. Alphabetical order must never determine a clinical treatment.
- DentalWin source procedure `86107` (`Ανασύσταση κοπτικής γωνίας m`) is the regression case for this rule: its verified filling behavior and `45` preset map to mesial plus facial surfaces. An entry previously saved as patient-level has no tooth/surface snapshot and must not be retroactively rewritten; it can be removed and re-entered after the corrected handling is active.
- Add explicit procedure defaults for drawing behavior (`WooksTools.onomaImage3`) and drawing color (`WooksTools.topa`). These defaults apply to new entries and may help review old rows; they do not replace row-level snapshots.
- Treat drawing behavior as a typed setting separate from the current broad handling mode and overlay kind. In particular, crown and veneer must not share one indistinguishable rendering path: DentalWin crowns use the complete tooth strip, while veneers use the `_o` artwork.
- Preserve unknown drawing modes and catalogue fields as raw migration metadata and put them in a review queue. Name-based overlay inference remains only a compatibility fallback for native Apexo records that predate explicit settings.
- Changing a catalogue surface, behavior, or color later must not repaint historical events.
- When a rebuilt guarded test server reuses the same URL, new catalogue batch IDs can coexist with older browser-local aliases. New-choice views reconcile only on immutable migration identity (`source_system` plus `source_stage_key`) against a successful full current-server catalogue inventory. The current remote ID is canonical; stale aliases remain available through direct ID lookup so historical events, treatment plans, and laboratory price references are not destructively rewritten. Deferred local edits and ambiguous identities are never hidden automatically, and display names are never used as a deduplication key.

### Rendering and asset plan

- Replace the current one-marker-per-overlay-kind reduction with a supersession-aware layer list. Exclude cancelled or explicitly superseded events, but do not discard an older independent restoration merely because a newer filling exists on the same tooth.
- Paint DentalWin-derived work in deterministic ascending source order (date, then stable source row ID), so later work appears above earlier work as in DentalWin. Native Apexo events use recorded time and stable event ID as the equivalent order.
- Keep the current neutral `assets/odontogram/v1/` anatomy intact. Introduce the supplied DentalWin-style pieces as a separately versioned restoration-mask package rather than silently replacing the base artwork.
- Preprocess the 92-pixel-wide multi-view strips into aligned, manifest-driven runtime masks. The manifest must record source hash, tooth, view, suffix/meaning, dimensions, offsets, and missing/invalid status. Runtime rendering should use the prepared assets directly to remain lightweight.
- Apply the event's saved color through the prepared alpha mask. DentalWin's observed 80% opacity is the initial fidelity reference, not a final UI decision until side-by-side validation confirms readability in Apexo.
- Define explicit assets/behaviors for complete-tooth crowns and `_o` veneers. `_o` must never be interpreted as occlusal. Missing artwork such as `36_o.png` enters asset review; do not silently substitute the crown image or claim exact fidelity.
- Keep a readable geometric surface selector in the UI. The shaped pieces overlap and are rendering masks, not exclusive pixel hit regions.

### Migration-pipeline revision

Implementation is now authorized. Mapping version `2026-09-05.phase6-surface-snapshot-v2` proceeds in this order:

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
- Corrected the drawing-behavior vocabulary after aggregate validation showed that real work rows store the Greek values `Εμφραξη`, `Στεφάνη`, and `Όψη`, not only the internal method-style names used by the synthetic fixture. Mapping v2 recognizes those verified values as filling, crown, and veneer while retaining method-style compatibility. Unknown values remain review-only.
- Rebuilt encrypted private staging as `2026-09-05.phase6-surface-snapshot-v2`. All four database source hashes remained unchanged, all 23 approved tables were extracted, duplicate external keys remained zero, and the run performed no Apexo writes.
- Aggregate-only eligibility analysis found 4,050 drawable events across 685 patients. Of 389 patients satisfying the pilot name/contact/appointment link requirements, 274 have at least one drawable event. The isolated selector now prioritizes five such patients while preserving the existing five-patient and two-appointments-per-patient caps.
- Created a separate empty loopback PocketBase review server with a verified pre-import backup and a guard fixed to mapping v2. Imported five patients, nine appointments, 58 canonical history rows, 15 therapy groups, 279 procedures, and 19 odontogram projections. The 19 projections retain canonical history links and saved material colors; no financial record was created.
- All base, treatment-history, catalogue, and projection verifiers passed with zero duplicate IDs. A second projection run created zero rows and reported all 19 projections and 19 provenance rows as already imported.
- The isolated pilot status mapping is provisionally `initial_condition -> existing`, `alternative_plan -> planned`, and `performed_work -> completed` unless the row is explicitly a staged plan item. This is a review policy, not production authorization.
- Primary teeth remain review-only because the current visible Apexo chart is permanent-dentition-only. Invalid teeth, malformed surfaces, unknown drawing modes, and ambiguous multi-tooth rows are not projected.
- Corrected catalogue handling so verified structured DentalWin metadata is evaluated before translated-name inference. This fixes source procedure `86107` without adding a one-off name rule, maps its drawing behavior to the filling overlay, and preserves explicit clinician overrides.
- Updated the guarded catalogue converter to emit explicit editable-surface or verified whole-tooth handling fields while leaving unknown/invalid cases unset for review. Focused verification passed 17 Dart catalogue tests and all 124 PowerShell migration assertions.
- Added one reusable, lightweight five-zone surface selector to catalogue defaults and native odontogram entry. It mirrors mesial/distal by FDI quadrant, adapts oral and centre terminology to jaw/tooth type, initializes from the procedure preset, and saves the clinician's final toggled set on the event rather than treating the preset as immutable.
- Added a read-only selected-tooth history panel beside the permanent-dentition chart on wide layouts (stacked below on narrow layouts). It filters the existing canonical event list with tooth-reference semantics, including bridge and removable-prosthesis links, and exposes every matching event through a bounded lazy scroll without creating another clinical record.
- Removed implicit first-procedure selection from odontogram entry and treatment planning. The group remains a navigation convenience, while procedure-dependent defaults and save actions stay inactive until the user explicitly selects a treatment.
- Added non-destructive catalogue alias reconciliation for repeated guarded imports served from the same loopback URL. Selection lists use the one current remote record for an unambiguous DentalWin migration identity, while old IDs remain resolvable for historical and financial references; no patient or clinical record is rewritten or deleted.

### Implementation log — 2026-09-06

- Verified the migrated PocketBase catalogue grouping before changing data: `Εμφυτεύματα` has 13 procedures, `Οδον. Χειρουργική 1` has 25, and no procedure references an unknown group. The incorrect visible choices were therefore a client picker-state defect, not a migration mapping defect.
- Corrected the reusable dependent search picker so a treatment-group change refreshes both pointer suggestions and keyboard-navigation state even when the old and new procedure selections are empty. Added a direct `Οδον. Χειρουργική 1` → `Εμφυτεύματα` odontogram regression test; the same correction applies to treatment planning.
- Replaced the odontogram clinical-status dropdown with five responsive, mutually exclusive one-click buttons. Each status has a distinct icon and localized label. At the owner's request, `completed` is the default for newly entered odontogram treatments; the saved event continues to use the existing status field without a schema or migration change.

### Working-beta migration rehearsal plan — 2026-09-06

The owner now wants to rehearse a serious migration with real DentalWin data in a working beta that can be carried between the practice and home. Android is explicitly outside this first rehearsal. This is a new planning goal, not authorization for a production import or for removing the existing safety locks.

#### Current readiness boundary

- The current standalone `ApexoDentalWinMigrator.exe` performs compatibility checks, read-only inventory, encrypted staging, and aggregate reporting only. It never writes to Apexo.
- The only implemented importer remains the deliberately guarded loopback pilot. It is hard-limited to five patients and two appointments per selected patient; treatment history and odontogram projections are limited to those same guarded patients. It must not be presented or repurposed as a full-clinic importer.
- A serious rehearsal therefore requires a new full-cohort **rehearsal importer and verifier**. It must preserve the current source-read-only, deterministic identity, idempotency, review-queue, no-finance, and rollback guarantees while using a newly initialized, explicitly identified rehearsal server.
- Demo mode and `Proceed offline` are not valid targets for real migration. They use device-local application storage, do not provide the server-side provenance and reconciliation records required by the migration, and are unsafe for carrying one authoritative dataset between computers.
- The existing mapping-v2 staging is useful as a development baseline, but not automatically the final rehearsal source: it contains 1,129 patients, 2,113 contacts, 4,253 appointments, 13,818 rows across the three chart-role work tables, and 9,797 review items. Only 1,801 appointments have the deterministic patient-GUID link; 497 are name-match candidates and 1,955 are unresolved. A calendar migration cannot be called complete unless the remaining 2,452 appointments are either safely presented as unlinked legacy events or explicitly accounted for in review.

#### Portable beta architecture

- A paid or hosted PocketBase service is not required for the rehearsal, but the PocketBase engine remains required as the authoritative data store. Package the compiled Apexo **Web** build, a pinned PocketBase runtime, schema/migrations, one loopback-only launcher, and the rehearsal `pb_data` tree as one portable kit. The Web build must be served by that PocketBase instance at the fixed loopback origin because the present Google Calendar authorization path is Web-only; the native Windows build is not the calendar-capable rehearsal client.
- If the kit is carried between computers, use an encrypted removable SSD (preferred over an ordinary USB flash drive), one Windows computer at a time, and a clean stop/eject sequence. Never start two copies against the same `pb_data`, copy it while PocketBase is running, or treat the carried drive as the only backup.
- Carry the dedicated `Data/BrowserProfile` with `pb_data` and include both directories in every complete portable backup. Flutter/Hive state is not wholly disposable: treatment plans and some settings remain browser-local, so clearing or omitting this profile can lose rehearsal work that PocketBase cannot rebuild. Google authorization is still device-sensitive and outside the migration record-count acceptance criteria; expect to reauthorize after a browser restart, token expiry, or transfer to another Windows account/computer. Never use a normal or incognito browser profile for this rehearsal.
- Before travel, create and verify a separate PocketBase backup on a different encrypted device. A lost, stolen, corrupted, or abruptly removed portable drive must be recoverable without touching the DentalWin source.
- Do not include the DentalWin source copy, encrypted staging, or staging key in the routine carry kit after the rehearsal import. They are recovery/migration materials with a different access boundary from the application data.

#### Proposed first serious rehearsal scope

The first full-cohort rehearsal should include only domains that already have a verified target and verifier path:

1. therapy groups and the procedure catalogue;
2. all DentalWin patients and structured contacts, using source identity rather than name matching;
3. only appointments with a deterministic DentalWin patient GUID link, plus explicitly unlinked legacy appointments if the target presentation and review workflow are implemented before the run;
4. canonical read-only treatment history for all patients;
5. eligible permanent-tooth odontogram projections linked one-to-one to canonical history, using mapping `2026-09-05.phase6-surface-snapshot-v2` or an explicitly versioned successor.

Keep these domains staged or review-only in the first rehearsal: name-only appointment candidates, primary teeth, invalid or multi-tooth references, unknown drawing modes, missing restoration artwork, unverified treatment lifecycle/status relationships, medical-history activation, patient documents/binary images, appointment audit logs, recalls, secondary work tables beyond their currently verified chart role, and all finance. No migrated treatment or odontogram projection may create an active charge, payment, balance, or invoice.

#### Required operator sequence

1. Close DentalWin and make a new complete copy of the final source folder. Do not use the live folder and do not omit linked image/document directories.
2. Record SHA-256 fingerprints and an aggregate inventory from that copy. Compare its counts with the 2026-08-26 source snapshot; explain every change rather than assuming the old staging remains current.
3. Run a new encrypted private dry run into a new empty directory with its key stored separately. Verify source hashes again after extraction and verify every protected envelope and checksum.
4. Produce an aggregate go/no-go report: source/staged row equations, deterministic versus unresolved appointment counts, treatment/catalogue links, odontogram eligibility and review reasons, and an explicit zero-active-finance statement.
5. Initialize a brand-new loopback-only portable PocketBase rehearsal server. Pin its runtime/schema versions, create an immutable pre-import backup, verify the backup by opening or restoring it in an isolated directory, and write a guard containing the source fingerprint, staging batch, mapping version, allowed stores, and server-data identity.
6. Import in bounded checkpoints: catalogue; patients/contacts; deterministic appointments; canonical treatment history; eligible odontogram projections. Stop after each checkpoint, reconcile counts/links/duplicate IDs, and take a named checksum-verified target snapshot.
7. Run the same batch a second time. Acceptance requires zero new clinical records, zero new charges, and every eligible row reported as `already_imported` or an explicitly approved versioned update.
8. Have the owner inspect a private representative sample in the application: Greek names and contacts, dates/times, a patient with multiple appointments, catalogue-linked and custom work, O/MO/OD/MOD and cervical fillings, overlapping restorations, crowns, veneers, general/no-tooth work, and review-only exceptions. Patient identifiers used for sampling must remain in a protected local checklist, not in Git or aggregate reports.
9. Reconcile the complete rehearsal: source rows equal imported/linked/already-imported/review/excluded/error rows for every included table; every imported child has its required parent; all provenance identities are unique; DentalWin hashes are unchanged; target backup restore is proven.
10. Only after owner sign-off should the portable kit be used for workflow testing at the practice and home. It remains a disposable rehearsal data set. A later production cutover requires a fresh final DentalWin snapshot, a fresh dry run, a separate backup and approval, and an explicit policy for any edits made in the rehearsal beta.

#### Inputs and decisions required from the owner

- A fresh complete DentalWin folder copy made while DentalWin is closed, or confirmation that the existing 2026-08-26 copy is intentionally the rehearsal source.
- An encrypted removable SSD or other approved local storage location, plus a different encrypted destination for backups. The encryption recovery key must be stored separately.
- Confirmation that the first rehearsal may exclude active finance, binaries/documents, medical-history activation, unresolved/name-only appointments, primary teeth, and other review-only rows as listed above.
- A short private list of representative patients/cases to inspect, referenced by DentalWin IDs rather than placed in Git documentation.
- Owner decisions on treatment statuses and cancellation semantics before those values can be treated as more than provisional display metadata.
- A workflow decision: edits made in the rehearsal are either disposable feedback, exported separately for review, or preserved through a later, explicitly designed rebase/cutover process. They must not silently overwrite a newer DentalWin snapshot.

#### Exact next deliverable and acceptance gate

The next implementation deliverable is **not** a production migration. It is a versioned full-cohort rehearsal-import package consisting of: a loopback-only portable launcher; a newly guarded importer for the five approved domains above; checkpoint backup/restore scripts; aggregate reconciliation and idempotency verifiers; a private exception-review file; and an operator runbook with stop/eject/recovery instructions. It is accepted only when automated synthetic tests, an empty-server full-cohort rehearsal, repeat-import zero-duplication checks, complete row accounting, and a demonstrated restoration from the pre-import backup all pass.

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

## Recommended next validation before production projection/import authorization

Use the guarded five-patient loopback pilot to compare an MOD filling, a cervical filling, two independent restorations on one tooth, a crown, a veneer, and a planned treatment later completed. Validate tooth/surfaces/date/status, original color and blending, layer order, source linkage, and repeat-import behavior. The current 19 projections prove import integrity and idempotency, not final visual or clinical approval. Primary teeth, unusual or multi-tooth values, unknown drawing modes, and missing/misnamed asset cases need explicit review. Exact 2D visual fidelity has not yet been approved in a live side-by-side test. DentalWin Cloud and complete 3D parity are outside the verified scope.

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
