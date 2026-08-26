# DentalWin Migration Phase 4 Pilot Verification

Date: 2026-08-26

Status: **Isolated empty-server pilot imported and verified**

Phase 4 imported a deliberately small DentalWin pilot into a disposable PocketBase server bound only to `127.0.0.1:8093`. It did not connect to a production server and did not modify DentalWin.

## Safety boundary

- Test server: explicit IPv4 loopback only
- Starting state: empty Apexo schema with 0 data records
- Offline pre-import backup: created and checksum-verified
- Pilot limit: 5 patients
- Appointment limit: 2 per selected patient
- Allowed target stores: `patients`, `appointments`, `migration_external_identifiers`, and `migration_batches`
- Production import authorized: no
- Writes to DentalWin: 0
- DentalWin executables run: 0
- Private source, staging, server data, backup, reports, and keys excluded from Git: yes

The safety lock refuses hostname aliases, LAN addresses, HTTPS variants, URL paths, a non-empty unguarded server, a mismatched staging batch, and records outside the pilot allow-list.

## Pilot result

| Target record type | Imported |
|---|---:|
| Patients | 5 |
| Appointments | 10 |
| External-identity/provenance records | 15 |
| Migration batch markers | 1 |
| **Total** | **31** |

The same import was executed a second time. It created 0 new records and recognized all 31 existing records, proving repeat-run idempotency for the pilot.

## Verification result

- All 5 patients have surname and first name.
- All 5 patients have at least one staged contact method.
- All 5 patients have a parsed birth date.
- All 5 selected names contain Greek characters, confirming Unicode transport through staging, PocketBase, and the API.
- All 10 appointments have a valid date, positive duration, and a valid link to one of the 5 imported patients.
- Duplicate PocketBase record IDs: 0.
- Production authorization flags: false.
- Phase 3/4 automated migration assertions passed: 54.
- Focused Flutter patient model and patient-fields widget tests passed: 25.

Only patient demographics, contacts, and linked appointment shells are in this pilot. Clinical treatments, tooth/surface semantics, medical history, images, and financial values remain excluded until their mappings are separately approved.

## Private artifacts

```text
dentalwin_migration_private/phase4-source-staging-2026-08-26/
dentalwin_migration_private/phase4-empty-test-server/
dentalwin_migration_private/phase4-empty-test-server/backup-pre-import-2026-08-26/
dentalwin_migration_private/keys/dentalwin-phase3.key
dentalwin_migration_private/keys/phase4-test-server-password.key
```

These paths contain private data or secrets and are ignored by Git. The repository contains only migration code, safety tests, and aggregate-only verification documentation.

## Recovery

The pre-import backup represents the empty, initialized Apexo schema before patient records were added. To restore it, stop the isolated PocketBase process, replace only the exact private `phase4-empty-test-server/pb_data` directory with the verified backup contents, and restart the loopback server. Never apply this backup to another server or production directory.

## Next approval gate

The isolated pilot does **not** authorize a larger or production import. A separate approval is required before expanding the patient batch, importing clinical/medical/financial domains, or connecting to any non-disposable server.
