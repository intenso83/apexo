# Apexo DentalWin Migrator (standalone Windows utility)

`ApexoDentalWinMigrator.exe` is a single-file Windows GUI around the verified
DentalWin migration engine in `tool/dentalwin_migration`.

## What v0.1 does

- checks both 64-bit and 32-bit Windows PowerShell for an installed Microsoft
  ACE OLE DB provider;
- inventories a copied DentalWin folder through read-only Access connections;
- fingerprints every `.mdb` before and after reading it;
- creates authenticated, encrypted row-level staging;
- keeps the encryption key outside the staging run with Windows account-only
  file permissions;
- shows only aggregate reports in the GUI;
- never writes to DentalWin;
- never connects to Apexo or PocketBase.

The executable contains the migration engine and synthetic fixture as embedded
resources. It uses Windows PowerShell, which is part of supported Windows
versions. Reading `.mdb` files still requires a matching 32-bit or 64-bit
Microsoft Access Database Engine (ACE) provider. The compatibility check tells
the operator which architecture is available.

## Why production import is disabled

The current fork has verified targets for the patient/appointment pilot and the
read-only treatment-history pilot, but its final versioned medical-history
model is not implemented yet. V0.1 therefore prepares and reconciles the full
migration without forcing clinical information into temporary or incorrect
fields.

## Build

From the repository root:

```powershell
pwsh -NoProfile -File tool/dentalwin_migrator/Build-DentalWinMigrator.ps1
```

The executable and SHA-256 build manifest are written to
`output/dentalwin-migrator/`.

## Operator sequence

1. Close DentalWin and make a verified copy of its data folder.
2. Open `ApexoDentalWinMigrator.exe`.
3. Select the copied folder, not the live clinic folder.
4. Run **Compatibility check**.
5. Run **Read-only inventory** and review its aggregate report.
6. Run **Encrypted dry run** and retain the separate key on the same Windows
   account.
7. Do not move row-level staging to cloud storage or send it by email.

The dry run produces no Apexo records. A later explicitly approved version can
consume the same guarded staging format after every target domain is ready.
