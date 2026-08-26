# DentalWin Migration Phase 3 Verification

Date: 2026-08-26

Status: **Private dry run completed and verified**

Phase 3 extracted the supplied DentalWin copy through read-only Access connections into encrypted private staging. It did not connect to or write to Apexo/PocketBase.

## Safety result

- DentalWin databases found: 4
- Approved clinical/calendar tables extracted: 23
- Source SHA-256 hashes unchanged: yes
- Duplicate migration identity keys: 0
- Writes to DentalWin: 0
- Writes to Apexo/PocketBase: 0
- DentalWin executables run: 0
- Key stored outside the staging run: yes
- Private source, staging, and key excluded from Git: yes

The dental-reference and medication-reference databases remain inventory-only until their semantics are approved. Large binary database values are represented by SHA-256 and byte length during the dry run; their original bytes remain in the unchanged DentalWin copy.

## Reconciled source counts

| Domain | Source rows | Staged rows |
|---|---:|---:|
| Patients | 1,129 | 1,129 |
| Contacts | 2,113 | 2,113 |
| Medical-history revisions | 813 | 813 |
| Therapy groups | 14 | 14 |
| Procedure catalogue | 279 | 279 |
| Clinical work and treatment-plan items | 11,072 | 11,072 |
| Appointments | 4,253 | 4,253 |
| Patient images and radiographs | 948 | 948 |
| Patient notes | 321 | 321 |
| Recalls | 78 | 78 |
| Finance candidates | 1,259 | 1,259 |

Additional raw-only records were retained, including 23,967 appointment log rows, 1,997 `WorksPelatiD` rows, 749 `WorksPelatiU` rows, and 118 primary-tooth rows.

## Protected review queue

The dry run retained 6,845 review items. These are not discarded rows and do not mean the extraction failed.

| Review reason | Rows |
|---|---:|
| Finance semantics not yet verified | 1,259 |
| Legacy/custom work not linked by catalogue code | 2,961 |
| Appointment patient unresolved | 1,955 |
| Appointment unique-name candidate | 497 |
| Finance patient unresolved | 135 |
| Ambiguous or invalid tooth value | 21 |
| Unknown contact type | 6 |
| Document patient unresolved | 6 |
| Uncategorized catalogue work | 3 |
| Orphan medical-history row | 2 |

Patient-visible values and row-level review information remain inside encrypted files. Ordinary reports contain only counts and reason codes.

## Verification performed

- 46 automated assertions passed against generated fake Access databases.
- 41 generated files passed SHA-256 checksum verification.
- All 36 protected staging envelopes passed authenticated decryption.
- Every decrypted protected file reconciled to its aggregate expected row count.
- Wrong-key and tamper detection tests passed.
- Protected files did not expose test patient names in plaintext.
- The real DentalWin source hashes were checked before extraction, after extraction, and after staging.

## Private artifacts

The real run is stored locally under:

```text
dentalwin_migration_private/phase3-private-dry-run-2026-08-26/
```

The separate restricted key is stored under:

```text
dentalwin_migration_private/keys/dentalwin-phase3.key
```

Both locations are ignored by Git. Do not email, cloud-sync, or share the source copy, staging directory, or key. Do not store the key together with a copied staging directory.

## Recovery

If the encrypted staging run is damaged, create a **new empty run directory** and rerun Phase 3 from the unchanged DentalWin copy. If the key is lost, the existing encrypted staging cannot be decrypted, but a new key and a new staging run can be generated from the unchanged source copy.

The migration code, mapping rules, tests, and aggregate documentation are version-controlled. The real patient data and encryption key are deliberately not version-controlled.

## Next approval gate

Phase 4 is **not approved**. No test or production Apexo import may begin until the owner separately approves an isolated empty test-server import and the protected review decisions required for that test are defined.
