# Apexo Patient Import Utility

Standalone Windows utility for importing an already-reviewed, contact-only CSV into either:

- DentalWin V6/V7 (`dental.mdb` / compatible Access database); or
- the Apexo fork's PocketBase `data` collection.

The two targets are intentionally separate. A DentalWin import never triggers Apexo, and an Apexo import never touches DentalWin.

## Recommended workflow

```text
consented scans
      ↓
ChatGPT extraction to the agreed structured CSV
      ↓
human review/correction of every value
      ↓
Validate CSV in the utility
      ├── DentalWin dry run → explicit confirmation → DentalWin import
      └── Apexo dry run     → explicit confirmation → Apexo import
```

The original CSV is read-only input and is never rewritten. Every validation and target report contains row numbers, counts, hashes, and reason codes only—not patient values.

## CSV contract

The utility requires the exact V6/V7 header and column order previously agreed for `patients_import.csv`. Identifiers remain text so leading zeroes are preserved. Dates may be supplied as ISO `YYYY-MM-DD` or an unambiguous supported day-first form; they are validated before use.

Required for each row:

- `index` as a unique integer;
- `last_name`;
- `first_name`.

The utility validates email, mobile length, dates, postal code, AMKA plausibility, AFM checksum, target field lengths, duplicate indices, and duplicate identities inside the CSV.

This release remains contact-only. `patient_notes`, every `history_*` column, and any non-zero `hist_*` flag block import. Unknown information must remain blank; the utility does not invent defaults.

## DentalWin target

The confirmed mapping is:

| CSV | DentalWin |
|---|---|
| `last_name` | `Customers.NAME` |
| `first_name` | `Customers.LAST` |
| `profession` | `Customers.EPPAGGELMA` |
| `address` | `Customers.PEDIO2` |
| `city` | `Customers.PEDIO3` |
| `area` | `Customers.PEDIO4` |
| `postal_code` | `Customers.PEDIO5` |
| `afm` / `doy` / `amka` | same-named `Customers` columns |
| `birth_date` | `Customers.HMGENN` |
| `registration_date` | `Customers.imerominia` |
| `referrer` | `Customers.SISTISAS` |
| `mobile` | `CustomerEpikoinonies`, type `2` |
| `email` | `CustomerEpikoinonies`, type `4` |

Safety behavior:

- validates the exact `Customers` and `CustomerEpikoinonies` schema;
- refuses import when a matching `.ldb` lock indicates DentalWin is open;
- records and rechecks both CSV and database SHA-256 hashes;
- identifies existing matches by AMKA, AFM, email, normalized mobile, or name plus birth date;
- skips duplicate candidates and never merges them automatically;
- creates and verifies a full database backup under `ApexoImportBackups`;
- inserts the complete batch in one Access transaction;
- rolls back the transaction on failure;
- verifies every new `Customers.EPON` after commit.

Always test on a current copied database first. Close DentalWin before a live import and keep the generated backup.

## Apexo target

The utility authenticates with a normal Apexo user or PocketBase superuser and writes patient records to the same `data` collection and `patients` store used by the fork.

- Remote targets require HTTPS; plain HTTP is accepted only for loopback test servers.
- Passwords and authentication tokens are held in memory and are never written to reports.
- The dry run reads existing patient identities for duplicate detection but never logs their values.
- New patient and contact IDs are deterministic for the CSV row.
- Existing matches are skipped; there is no automatic merge or overwrite.
- Partial creates are deleted if the batch fails, then the operation reports whether rollback was complete.
- The target patient fingerprint must remain unchanged between dry run and import.

Because DentalWin and Apexo are different databases, there is no cross-system transaction. Run and verify each target independently.

## GUI

1. Double-click `ApexoPatientImportUtility.exe`.
2. Open **1. Import checked CSV** and select the reviewed CSV.
3. Click **Validate CSV**.
4. Select a DentalWin database and run **DentalWin dry run**, or enter Apexo server credentials and run **Apexo dry run**.
5. Review the new/duplicate/already-imported counts.
6. Use only the corresponding target's import button and type the displayed confirmation phrase.
7. Retain the audit JSON from the CSV's `ApexoImportReports` folder.

The optional OCR and Excel-review tabs remain available, but they are not required for a ChatGPT-generated reviewed CSV.

## Command line

Validation only:

```powershell
ApexoPatientImportUtility.exe --reviewed-csv patients_import.csv
```

DentalWin dry run:

```powershell
ApexoPatientImportUtility.exe `
  --reviewed-csv patients_import.csv `
  --target dentalwin `
  --database D:\DentalWinTest\dental.mdb
```

The JSON output contains the CSV SHA-256. A commit requires its first 12 characters explicitly:

```powershell
ApexoPatientImportUtility.exe `
  --reviewed-csv patients_import.csv `
  --target dentalwin `
  --database D:\DentalWinTest\dental.mdb `
  --commit --confirm 0123456789ab
```

For Apexo, keep the password in a local restricted file rather than passing it on the command line:

```powershell
ApexoPatientImportUtility.exe `
  --reviewed-csv patients_import.csv `
  --target apexo `
  --apexo-url https://your-apexo-server.example `
  --apexo-email operator@example.com `
  --password-file C:\Private\apexo-password.txt
```

## Build and verification

Build requirements apply only to the developer machine; the resulting EXE includes Python and its document dependencies.

```powershell
pwsh -NoProfile -File tool\dentalwin_ocr\Build-ApexoOcr.ps1 -Python python
```

The build runs unit/integration tests, creates a one-file Windows EXE, verifies PDF/Excel/CSV internals, and initializes the packaged GUI runtime.
