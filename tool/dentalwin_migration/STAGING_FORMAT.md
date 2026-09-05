# Private staging format v1.1

The Phase 2/3 staging format separates safe aggregate reports from protected row-level content.

```text
run-directory/
├── .dentalwin-private-staging
├── manifest.json
├── checksums.sha256
├── reports/
│   ├── summary.json
│   ├── extraction.json
│   └── summary.md
└── protected/
    ├── raw/
    │   └── <source-table>.jsonl.enc.json
    └── normalized/
        ├── patients.jsonl.enc.json
        ├── patient_contacts.jsonl.enc.json
        ├── medical_history_revisions.jsonl.enc.json
        ├── therapy_groups.jsonl.enc.json
        ├── procedure_catalog.jsonl.enc.json
        ├── clinical_events_and_plan_items.jsonl.enc.json
        ├── appointments.jsonl.enc.json
        ├── patient_documents.jsonl.enc.json
        ├── patient_notes.jsonl.enc.json
        ├── recalls.jsonl.enc.json
        ├── ledger_candidates.jsonl.enc.json
        ├── external_identifiers.jsonl.enc.json
        └── review_items.jsonl.enc.json
```

## Safe files

The following files must not contain patient values:

- `manifest.json`;
- `checksums.sha256`;
- `reports/summary.json`;
- `reports/extraction.json`;
- `reports/summary.md`.

They may contain:

- format and mapping versions;
- batch ID;
- source/database fingerprints;
- relative database names and roles;
- table and staged-entity counts;
- schema column names;
- review reason codes and counts;
- completeness and source-hash results.

## Protected files

Each `*.jsonl.enc.json` file is an authenticated encrypted envelope:

```json
{
  "format": "apexo-dentalwin-encrypted-v1",
  "kdf": "PBKDF2-HMAC-SHA256",
  "iterations": 210000,
  "cipher": "AES-256-CBC",
  "integrity": "HMAC-SHA256",
  "salt": "base64",
  "iv": "base64",
  "ciphertext": "base64",
  "hmac": "base64"
}
```

The plaintext inside the envelope is UTF-8 JSON Lines: one JSON object per line. The passphrase is never written into the envelope or staging directory. Private mode obtains it from a separate restricted key file.

The HMAC is calculated over `salt + iv + ciphertext`. Decryption refuses a wrong passphrase or modified ciphertext.

## External identity key

Every staged target candidate receives a stable identity in this shape:

```text
source database fingerprint / source table / source record key / target entity type
```

A repeated run over the unchanged source and mapping version must produce the same external keys. Duplicate external keys are an error.

## Review records

A review record contains only the minimum identifiers needed to find its protected source row plus:

- reason code;
- severity;
- status;
- source table;
- source record key.

Review decisions and patient-visible values belong in protected storage.

## Odontogram surface snapshots (v1.1)

Procedure rows preserve DentalWin `onomaImage`, `onomaImage3`, and `topa` as
raw values beside `default_surfaces`, `default_cervical_surfaces`, normalized
drawing behavior, and unsigned packed ARGB color when each value is valid.

Clinical work rows from `WorksPelatiU`, `WorksPelatiD`, and `WorksPelati`
preserve their source table and chart role (`initial_condition`,
`alternative_plan`, or `performed_work`). They retain the original
`LOGARIASMOIB`, `LOGARIASMOIA`, `OikonomikiID`, and `LOGARIASMOIC` values beside
normalized surfaces, cervical locations, drawing behavior, and color.

Only digits `1`, `2`, `4`, `5`, `6`, `7`, and `8` are normalized. Repeated,
unknown, or mixed surface values remain raw and create an explicit review item.
Unknown drawing behavior and invalid packed color follow the same rule; the
pipeline does not infer replacements from treatment names.

## Binary fields

Large binary Access values are staged as `binary_deferred`, `length_bytes`, and `sha256`. This proves identity and presence without duplicating sensitive image bytes during the dry run. The unchanged DentalWin copy remains the source for controlled binary transfer in a later import phase.

## Phase boundary

Phase 3 may produce encrypted real-data staging and aggregate-only reports. It still cannot connect to or write to Apexo/PocketBase. A separate approval is required for an empty test-server import.
