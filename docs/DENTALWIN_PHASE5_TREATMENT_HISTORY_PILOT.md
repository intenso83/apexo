# DentalWin Migration Phase 5 Treatment-History Pilot

Date: 2026-08-27

Status: **Isolated treatment-history pilot imported and verified**

Phase 5 expanded only the existing five-patient Phase 4 pilot on the disposable PocketBase server bound to `127.0.0.1:8093`. It imported historical DentalWin treatment events into a new read-only Apexo store and UI tab. It did not connect to production and did not modify DentalWin.

## Safety boundary

- Test server: explicit IPv4 loopback only
- Patient scope: exactly the five already-guarded Phase 4 patients
- Treatment cap: 500 per patient and 2,500 total
- New target store: `treatment_history`
- Provenance: one `migration_external_identifiers` record per treatment
- Production import authorized: no
- Writes to DentalWin: 0
- DentalWin executables run: 0
- Treatment plans, invoices, payments, images, and medical histories written: 0
- Private source, staging, server data, reports, and keys excluded from Git: yes

The importer reuses the Phase 4 guard marker and staging batch. It refuses a non-loopback URL, an unguarded server, a mismatched staging batch, an unknown patient, an unexpected existing store, or records beyond the fixed limits.

## Pilot result

| Treatment-history check | Result |
|---|---:|
| Pilot patients | 5 |
| Historical treatment records | 121 |
| Completed treatment events | 121 |
| Treatment-plan events in this five-patient sample | 0 |
| Records with a valid event date | 121 |
| Records with a normalized FDI tooth value | 82 |
| Legacy custom/unmatched treatments retained verbatim | 26 |
| Treatment provenance records | 121 |
| Duplicate target IDs | 0 |

Zero plan events is a property of this particular five-patient source sample, not a limitation of the model: the importer and UI support both completed and planned event kinds.

## Clinical fidelity rules

- Source treatment names and notes are retained without inventing new clinical meaning.
- Source tooth values are preserved verbatim and normalized to FDI only when the mapping is safe.
- Catalog matches record their source catalog code and matching method.
- Unmatched work names remain visible as legacy custom treatments.
- Historical entries are read-only and visually separated from Apexo's editable future treatment-plan workflow.
- Blank or uncertain dates remain explicitly unavailable rather than being guessed.

## UI result

The patient panel now includes a **Treatment history** tab for saved patients. The timeline shows completed/planned status, date, treatment name, tooth, therapy group, legacy-custom status, notes, and the historical total when present. The tab cannot edit or delete imported history.

## Verification result

- Exact imported count matched the encrypted staged source count: 121.
- Every treatment links to one of the five guarded pilot patients.
- Every treatment has a matching provenance record.
- All migration guard and staging-batch identifiers match the approved pilot.
- Duplicate deterministic record IDs: 0.
- Production authorization flags: false.
- Automated PowerShell migration assertions passed: 62.
- Focused Flutter treatment-history and patient-fields tests passed: 29.
- Targeted static analysis for the new treatment-history code passed with no issues.

The repository-wide analyzer still reports pre-existing warnings and informational findings elsewhere in Apexo; no new error was introduced by this pilot.

## Private artifacts

All patient-level staging data, reports, PocketBase data, backups, and passwords remain under `dentalwin_migration_private/`, which is ignored by Git. This document intentionally contains aggregate counts only.

## Recovery

The verified Phase 4 pre-import backup remains the clean restoration point. To return to it, stop only the disposable PocketBase process, replace only the exact private test server's `pb_data` directory with its checksum-verified backup, and restart the loopback server. Never apply this backup to another server or production directory.

## Next approval gate

Phase 5 does **not** authorize a larger patient batch, production import, treatment editing, automatic billing, or clinical remapping. Each expansion needs a separate mapping review and explicit approval.
