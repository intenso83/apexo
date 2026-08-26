# DentalWin Migration Phase 2 Verification

Date: 2026-08-26

Status: Phase 2 implemented and verified (historical checkpoint)

## Implemented

- Windows ACE OLE DB inventory reader using `Mode=Read`;
- SHA-256 source fingerprints before and after every inventory operation;
- database-role detection and critical schema/count inventory;
- private authenticated-encryption staging format;
- raw-row and normalized-entity staging separation;
- stable external identity keys and duplicate detection;
- aggregate-only Markdown and JSON reports;
- review reason codes for unmatched and ambiguous records;
- synthetic patient, contact, medical-history, catalogue, treatment, plan, appointment, document, note, recall, and finance transformations;
- an explicit Phase 3 lock preventing real patient-row staging.

## Automated verification

Command:

```powershell
pwsh -NoProfile -File tool/dentalwin_migration/tests/Run-Tests.ps1
```

Result: **30 assertions passed**.

Verified behaviours include:

- deterministic repeat-run batch identity;
- no duplicate external source keys;
- source fixture unchanged;
- every synthetic row accounted for;
- treatment-plan membership retained;
- legacy/custom work retained;
- ambiguous tooth values routed to review;
- patient-GUID appointment linking separated from name-only review candidates;
- correct-passphrase decryption;
- wrong-passphrase rejection;
- tamper detection;
- no patient names or identifiers visible in protected staging plaintext;
- checksum generation;
- two generated synthetic `.mdb` databases recognized as clinical and calendar sources;
- both synthetic database hashes unchanged after inventory;
- refusal to place output inside the source folder;
- refusal to run Phase 3 `PrivateDryRun`.

## Aggregate inventory of the supplied copy

The Phase 2 inventory mode was run against the copied DentalWin folder. It did not extract patient rows.

| Detected database role | User tables | Critical tables inventoried | Hash unchanged | Error |
|---|---:|---:|---|---|
| Clinical | 445 | 18 | Yes | No |
| Dental reference | 411 | 18 | Yes | No |
| Medication reference | 11 | 0 | Yes | No |
| Calendar | 16 | 5 | Yes | No |

Result:

- 4 databases found;
- inventory completed;
- all four source hashes remained unchanged;
- no DentalWin executable was run;
- no DentalWin database was written;
- no connection to Apexo/PocketBase was made;
- no real patient rows were staged.

## Private artifacts

The real inventory output is stored under the Git-ignored `dentalwin_migration_private/` directory. It contains fingerprints, schema metadata, counts, and checksums. It is deliberately not committed.

## Next approval gate

Phase 3 was subsequently approved and completed. See [DentalWin Migration Phase 3 Verification](DENTALWIN_PHASE3_VERIFICATION.md). This Phase 2 report remains the historical pre-extraction checkpoint.
