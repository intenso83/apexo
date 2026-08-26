# DentalWin migration tool

This Windows-only tool implements Phases 2 and 3 of the approved DentalWin migration blueprint.

It can:

- inventory copied Microsoft Access `.mdb` databases through ACE OLE DB in read-only mode;
- fingerprint every source database before and after inventory;
- report table schemas and row counts without printing patient values;
- run a complete synthetic dry run with fake DentalWin-shaped records;
- run a full private read-only dry run against the copied DentalWin databases;
- create password-protected raw and normalized staging files;
- create stable provenance keys, review queues, aggregate reports, and checksums;
- prove repeat-run idempotency with automated tests.

It cannot:

- write to DentalWin;
- run DentalWin executables;
- connect to or write to Apexo/PocketBase;
- import a staged batch into Apexo/PocketBase.

## Requirements

- Windows;
- PowerShell 7 (`pwsh`);
- Microsoft Access Database Engine with `Microsoft.ACE.OLEDB.16.0` or `12.0`.

## Run the automated Phase 3 tests

From the Apexo repository root:

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/tests/Run-Tests.ps1
```

The test suite creates two temporary synthetic Access databases and fake patient-shaped records. It contains no real patient information. It also tests the private extraction path, encryption, key separation, tamper rejection, source hashes, and the no-Apexo-write boundary.

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
