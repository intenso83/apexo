# Odontogram and Therapy-Catalogue Foundation

Date: 2026-08-27

Status: **Foundation implemented, including explicit surface, bridge, and removable-prosthesis targets**

This package creates the safe foundation for Apexo's future clinical odontogram. It intentionally does not replace the existing Dental Notes selector yet. Both remain available while the new model is tested and expanded.

## What is available

- A versioned set of permanent-tooth images under `assets/odontogram/v1/`.
- All 32 adult FDI teeth rendered from 48 supplied right-side master images.
- Facial, occlusal/incisal, and oral views for every tooth.
- Runtime mirroring for left quadrants, so the source artwork is reused consistently.
- Exact surface selection for mesial, distal, facial, oral, occlusal/incisal, or whole tooth.
- An explicit **No surface specified** choice. The treatment remains in history but is not drawn on a tooth.
- A patient-level odontogram event timeline with condition/treatment kind and status.
- Connected bridge records with abutment, pontic, and implant-abutment units.
- Arch-level removable-prosthesis records with optional replaced-tooth, clasp, rest, attachment, and implant-support components.
- An admin therapy catalogue with editable groups, colours, order, hidden state, prices, durations, target type, and optional surface presets.
- A guarded DentalWin catalogue importer for the isolated local test server.

## Asset contract

The archive contains neutral anatomy only. Clinical meaning is stored as data and drawn as overlays by Flutter; it is never baked into the PNG files.

| Item | Contract |
|---|---|
| Asset version | `v1` |
| Master teeth | FDI 11-18 and 41-48 |
| Runtime mirrors | 11-18 to 21-28; 41-48 to 31-38 |
| Views | facial, occlusal/incisal, palatal/lingual |
| Image format | transparent 256 x 256 RGBA PNG |
| Master images | 48 |
| Adult runtime combinations | 32 teeth x 3 views = 96 |

The supplied `manifest.csv`, README, generation report, and contact sheet are retained beside the assets so a future asset revision can be audited and introduced as `v2` without silently altering historic records.

## Clinical event model

Odontogram records are appendable clinical events, not just the current colour of a tooth. Each event stores:

- patient and FDI tooth;
- zero or more explicit surfaces;
- condition or treatment kind;
- existing, monitor, planned, completed, or cancelled status;
- therapy-group and procedure IDs;
- immutable group/procedure/price snapshots;
- recorded time, optional appointment link, notes, and optional superseded-event link;
- migration provenance when the event came from another system.

Whole-tooth selection cannot be combined with individual surfaces. A new treatment may also deliberately have no surface selected. It is still stored and shown in the treatment timeline, but it produces no tooth overlay. Imported historic records may likewise leave surfaces empty when DentalWin did not provide reliable surface information. The importer must never guess a surface.

### Treatment targets

The clinical target is stored separately from the procedure name:

| Target | Stored structure | Drawing rule |
|---|---|---|
| Patient-level | No tooth or arch mapping | History only |
| Tooth | One FDI tooth and zero or more surfaces | Draw only when at least one surface or whole-tooth target is selected |
| Bridge | One connected record with optional units: abutment, pontic, or implant abutment | Empty mapping is history only; a mapped bridge requires at least two unique teeth, support, and pontic units |
| Removable prosthesis | Upper/lower/both arch and optional tooth components | Draw only mapped replaced teeth, clasps, rests, attachments, or implant supports |

An empty bridge or removable mapping is valid because older records may identify the treatment without identifying clinically reliable teeth. A partially specified or internally inconsistent mapping is rejected instead of being guessed.

## Therapy catalogue

The catalogue separates reusable definitions from patient clinical events:

- `therapy_groups` stores group name, colour, order, hidden state, and source provenance.
- `procedure_catalog` stores procedure name, group, price, duration, target type, surface-selection behaviour, optional surface preset, hidden state, source code, and provenance.
- A preset such as O, MO, or MOD is only a default. The clinician can change it or choose **No surface specified** for the patient event.
- Surface codes are stored as structured data and are not embedded in the procedure name.
- Patient events retain snapshots, so renaming a catalogue item later does not rewrite history.
- Hiding is used instead of deletion so existing clinical links remain valid.

The administrator screen is available from the main navigation as **Therapy catalogue**. It supports search and adding or editing groups and procedures.

## Guarded DentalWin catalogue result

The importer was run only against the disposable PocketBase server at `127.0.0.1:8093` using the approved encrypted private staging batch.

| Import check | Result |
|---|---:|
| Source therapy groups | 14 |
| Target therapy groups | 15 |
| Source procedures | 279 |
| Procedures placed in explicit legacy-review group | 3 |
| Procedures with unknown tooth requirement retained as unknown | 157 |
| Duplicate deterministic IDs | 0 |
| Production authorization | false |

The extra target group is `Uncategorized legacy review`. It makes unmatched source links visible for human review instead of silently assigning clinical meaning.

## Safety boundary

- DentalWin files remain read-only and unchanged.
- The importer accepts only the explicit loopback test server and guarded private staging batch.
- Production import is not authorized.
- Patient-level staging, keys, PocketBase files, reports, and backups remain under ignored `dentalwin_migration_private/` paths.
- No patient names or identifiers are written into this document or Git.
- The old Apexo whole-tooth selector remains available during the beta period.

## Verification

- Focused Flutter odontogram/catalogue/widget tests: 19 passed, including no-surface recording and both prosthetic target editors.
- Localization completeness and audit checks: 36 passed across all five supported languages.
- Complete Flutter unit suite in serial mode: 1,680 passed.
- Asset checks: all 48 PNGs match the manifest, dimensions, transparency, and mirroring rules.
- PowerShell migration tests: 69 assertions passed.
- Targeted static analysis of the new/changed package files: no issues.
- Flutter web production build: completed successfully.
- Local rendered check: imported groups/procedures displayed, all three tooth views rendered, left-side mirroring worked, and the surface/procedure/status form displayed without overflow.
- Repository-wide static analysis still reports pre-existing warnings and informational lint findings elsewhere in Apexo.
- The full repository test run completed 1,762 tests with five environment-dependent live-backend failures. Those failures require a separate PocketBase fixture on port 8090 and share a locked Hive file; all new package tests passed in that same run.

The local debug server still emits Apexo's pre-existing DICOM WebAssembly cross-origin warning. It did not prevent the catalogue or odontogram from rendering and is outside this package.

## Deliberate limitations of this foundation

- Adult permanent dentition only; primary teeth are a later version.
- Surface, bridge-unit, arch, and removable-component selections are stored and validated, but their clinical visual overlays are the next layer.
- Bridge connectors and removable-prosthesis symbols are not drawn yet; the current screen previews and validates their mappings.
- Historical DentalWin treatment entries are not automatically converted into exact surface events unless their meaning can be mapped without guessing.
- This beta does not yet calculate billing or balances from odontogram events.
- It does not remove or rewrite the existing Dental Notes data.

## Next safe phase

1. Review the rendered tooth size, spacing, orientation, and three-view layout.
2. Approve the status colours and overlay legend.
3. Implement the first small overlay set: existing/planned/completed filling, crown, implant, root canal, and missing tooth.
4. Map only explicitly approved DentalWin work categories to those overlays.
5. Test editing, superseding, printing, and Android read-only presentation before any larger migration.

## Recovery

The package is saved as a Git checkpoint on the `codex/work-week-calendar-prototype` branch. The original ZIP remains in the workspace but is not required at runtime because its validated contents are versioned under `assets/odontogram/v1/`.

To inspect the checkpoint without changing current work, create a recovery branch from the recorded commit hash:

```powershell
git switch -c recovery/odontogram-foundation <checkpoint-hash>
```

The exact hash is recorded in the handoff after the checkpoint is committed.
