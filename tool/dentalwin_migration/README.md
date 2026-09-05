# DentalWin migration tool

This Windows-only tool implements Phases 2 and 3, the isolated Phase 4 patient/appointment pilot, the isolated Phase 5 treatment-history pilot, and the guarded odontogram-projection review pilot of the approved DentalWin migration blueprint.

It can:

- inventory copied Microsoft Access `.mdb` databases through ACE OLE DB in read-only mode;
- fingerprint every source database before and after inventory;
- report table schemas and row counts without printing patient values;
- run a complete synthetic dry run with fake DentalWin-shaped records;
- run a full private read-only dry run against the copied DentalWin databases;
- create password-protected raw and normalized staging files;
- create stable provenance keys, review queues, aggregate reports, and checksums;
- prove repeat-run idempotency with automated tests;
- initialize and guard a disposable empty PocketBase test server;
- import and verify a five-patient, two-appointments-per-patient pilot;
- import and verify historical DentalWin treatments for only those same five pilot patients;
- import DentalWin therapy-catalogue snapshots into that isolated server;
- create and verify one idempotent odontogram projection per eligible canonical history row.

It cannot:

- write to DentalWin;
- run DentalWin executables;
- connect to a non-loopback or production Apexo/PocketBase server;
- import patients outside the guarded five-patient pilot;
- import medical-history, image, or finance records during the pilot;
- project invalid, primary, ambiguous multi-tooth, or unknown drawing-behavior rows;
- connect either pilot to a production or non-loopback server.

## Requirements

- Windows;
- PowerShell 7 (`pwsh`);
- Microsoft Access Database Engine with `Microsoft.ACE.OLEDB.16.0` or `12.0`.

## Run the automated migration tests

From the Apexo repository root:

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/tests/Run-Tests.ps1
```

The test suite creates two temporary synthetic Access databases and fake patient-shaped records. It contains no real patient information. It also tests the private extraction path, encryption, key separation, tamper rejection, source hashes, the Phase 3 no-Apexo-write boundary, loopback URL locks, and deterministic Phase 4 IDs.

## Phase 4 isolated pilot

The Phase 4 commands are intentionally exposed as PowerShell module functions instead of a general-purpose production importer. They require:

- an explicit `http://127.0.0.1:<port>` URL;
- a healthy empty server initialized with Apexo's exact schema;
- a verified offline empty-server backup;
- a verified private staging batch and separate keys;
- a guard marker that fixes the staging identity, server, stores, and pilot limits.

`Invoke-DwPilotImport` writes only five patients, at most two appointments per selected patient, their provenance records, and one batch marker. `Test-DwPilotImport` verifies counts, required fields, Unicode names, appointment links and dates, duplicate IDs, and the absence of production authorization. Row-level reports remain private and ignored by Git.

## Phase 5 treatment-history pilot

Phase 5 is a separate, explicitly guarded expansion of the already-approved Phase 4 pilot. `Invoke-DwTreatmentHistoryPilot` writes read-only treatment-history records only for the same five imported patients. It also writes one provenance record per treatment. It does not create or change DentalWin treatments, Apexo treatment plans, invoices, payments, images, or medical-history records.

`Test-DwTreatmentHistoryPilot` compares the imported rows with the encrypted private staging data, verifies every patient link and migration guard, rejects duplicate IDs, and checks the exact provenance count. Reports are aggregate-only; patient-level values remain in the ignored private directory.

The pilot UI presents these rows on a separate read-only **Treatment history** tab. It deliberately does not translate uncertain legacy work names into editable Apexo treatments. Unmatched names are marked as legacy custom treatments so that no clinical meaning is invented during migration.

## Guarded odontogram-projection review pilot

The projection pilot is an isolated visual-review layer over the canonical Phase 5 history. It never creates another treatment or a financial record. The five-patient selector prefers otherwise eligible patients with at least one truthfully drawable permanent-tooth event so an owner can inspect visible results without widening the patient cap.

`Invoke-DwOdontogramProjectionPilot` accepts only:

- one valid permanent FDI tooth;
- one verified DentalWin drawing behavior: filling, crown, or veneer;
- valid source-row surfaces for fillings, or an explicit whole-tooth target for crowns and veneers;
- a matching canonical `treatment_history` row from the same guarded batch.

The current mapping recognizes both the internal method-style values and the real Greek DentalWin values `Εμφραξη`, `Στεφάνη`, and `Όψη`. Initial-condition, alternative-plan, and performed-work roles are preserved, while their Apexo statuses remain explicitly provisional pending owner review. Primary teeth, malformed surfaces, unknown drawing modes, and ambiguous multi-tooth values stay in review.

`Test-DwOdontogramProjectionPilot` verifies patient/history links, drawable targets, provenance, deterministic IDs, saved material colors, supported provisional statuses, and the absence of financial fields. Re-running the importer must report the same eligible rows as `already_imported` and create no duplicate projection or provenance rows.

## Run the committed synthetic dry run

Choose a new empty output folder each time:

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/Invoke-DentalWinMigration.ps1 `
  -Mode SyntheticDryRun `
  -FixturePath tool/dentalwin_migration/fixtures/synthetic_source.json `
  -OutputDirectory dentalwin_migration_private/my-synthetic-run
```

## Run an aggregate-only inventory of a copied DentalWin folder

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/Invoke-DentalWinMigration.ps1 `
  -Mode Inventory `
  -SourceDirectory DentalWin_reference `
  -OutputDirectory dentalwin_migration_private/my-inventory
```

Inventory mode records file hashes, database roles, selected schemas, and row counts. It does not extract or print patient rows.

## Private output

Use only a folder under `dentalwin_migration_private/`. That folder is excluded from Git.

Synthetic and real private row files use:

- PBKDF2-HMAC-SHA256 key derivation;
- AES-256-CBC encryption;
- HMAC-SHA256 integrity protection;
- a passphrase that is not stored in the staging directory.

Aggregate `manifest.json`, `summary.json`, and `summary.md` files contain counts, schema metadata, hashes, and review reason codes only. Protected row data is stored under `protected/`.

The fixed synthetic passphrase in the launcher is allowed only because the committed fixture is fake. Private mode creates or reads a random key from a separate file whose Windows access rules are restricted to the current account. The key is never accepted as a command-line value and is never stored inside the run directory.

## Run the private read-only dry run

Use a new output directory. The key file must remain separate from both the DentalWin source and the run directory:

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/Invoke-DentalWinMigration.ps1 `
  -Mode PrivateDryRun `
  -SourceDirectory DentalWin_reference/DentalWin `
  -OutputDirectory dentalwin_migration_private/my-private-run `
  -KeyFile dentalwin_migration_private/keys/dentalwin-phase3.key
```

If the key file does not exist, the launcher creates it with restricted Windows permissions. Do not delete it while the staging run may still be needed. Do not share the key together with the encrypted staging files.

## Safety behaviour

- The output folder must be new or empty.
- The output folder cannot be inside the DentalWin source folder.
- Access connections include `Mode=Read`.
- Source SHA-256 hashes are compared before and after inventory or extraction, and again after private staging completes.
- A changed source hash makes the run fail.
- Private mode extracts only the approved clinical and calendar tables. The two reference databases remain inventory-only until their meanings are approved.
- Binary database fields are represented in staging by their SHA-256 and byte length; the original bytes remain in the unchanged source copy for the controlled import phase.
- Private mode never opens an Apexo/PocketBase connection.

## Staging layout

See [STAGING_FORMAT.md](STAGING_FORMAT.md).
