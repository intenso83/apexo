# DentalWin Migration Blueprint

Status: Approved by owner; Phase 3 private dry run completed

Date: 2026-08-26

Owner approval recorded: 2026-08-26

Scope: Read-only extraction, staging, transformation, review, test import, reconciliation, and eventual migration from the supplied DentalWin copy into the Apexo fork

Related document: [Patient Fields Blueprint](PATIENT_FIELDS_BLUEPRINT.md)

This blueprint supersedes the older DentalWin discovery counts and relationship assumptions in the master specification wherever the two disagree; the supplied final copy is the controlling evidence for this migration.

## 1. Purpose

This blueprint defines how the useful contents of the supplied DentalWin copy will be preserved in the Apexo fork without modifying DentalWin, silently merging patients, losing unrecognized records, or pretending uncertain legacy meanings are known.

It covers:

- patients and contacts;
- external identifiers and migration provenance;
- medical-history revisions and legacy alerts;
- therapy groups and the dental-work catalogue;
- performed work, treatment-plan items, teeth, and odontogram history;
- appointments, appointment categories, labels, reminders, and external calendar identifiers;
- patient notes, recalls, images, radiographs, and documents;
- charges, payments, and other financial history;
- unresolved records and human review;
- dry-run, idempotency, reconciliation, backup, and rollback requirements.

This document does **not** authorize a production import. Phase 3 authorized only a private read-only extraction and dry-run report. Any Apexo import, including an empty test server, requires a separate approval after the dry run has been reviewed.

## 2. Safety boundary

The following rules are mandatory:

1. DentalWin is a source system and is never written to by the importer.
2. Discovery and test extraction use only a copied DentalWin folder.
3. DentalWin executables, services, macros, and unknown helper programs are not run.
4. The copied DentalWin folder remains excluded from Git.
5. Real patient data, databases, images, radiographs, signatures, exports, reports, and logs are never committed to Git or used as automated test fixtures.
6. Source databases receive a cryptographic fingerprint before a migration run. The source is checked again after the run to demonstrate that it did not change.
7. The importer must not connect to the production Apexo database while in inventory or dry-run mode.
8. A verified Apexo database-and-files backup is required before every test or production import.
9. A row is never silently discarded. Every source row must finish as `created`, `linked`, `already_imported`, `review_required`, `excluded_by_approved_rule`, or `error`.
10. Unknown information remains unknown. The importer must not invent dates, contact details, tooth surfaces, treatment statuses, prices, clinicians, or payment meanings.

## 3. Verified source snapshot

The following counts were measured from the supplied copy on 2026-08-26. They are validation expectations for this copy, not constants to hard-code into the importer.

| Domain | Source | Verified rows or items | Initial finding |
|---|---|---:|---|
| Patients | `Customers` | 1,129 | One authoritative source row per DentalWin patient candidate. |
| Contacts | `CustomerEpikoinonies` | 2,113 | All rows match a patient through `guidsspelati -> Customers.EPON`. |
| Medical history | `DentalSchoolIstoriko` | 813 | 811 rows match a patient by both numeric ID and DentalWin patient GUID; 2 require review. |
| Therapy groups | `Works_Kategories` | 14 | Includes hidden and placeholder-like categories requiring an import decision. |
| Dental works | `WooksTools` | 279 | Contains names, category, prices, tooth requirement, order, rendering metadata, and stable work codes. |
| Main clinical work | `WorksPelati` | 11,072 | Every row matches a patient by numeric ID and DentalWin patient GUID. |
| Treatment-plan flag | `WorksPelati.SxedioUerapias = 1` | 91 | Preserve as plan items; exact workflow/status meaning still needs visual confirmation. |
| Secondary work table | `WorksPelatiD` | 1,997 | Stage separately until its exact semantics are confirmed. |
| Secondary work table | `WorksPelatiU` | 749 | Stage separately until its exact semantics are confirmed. |
| Odontogram rows | `odontogrammata` | 0 | No active per-surface rows are available in this copy. |
| Tooth-state rows | `CustomerToothState` | 0 | Do not infer missing/existing tooth state from an empty table. |
| Primary-tooth rows | `NeogilaDontiaPelati` | 118 | Preserve primary-dentition information and source semantics. |
| Appointments | `Appointments2` | 4,253 | 1,801 contain a patient GUID and all 1,801 match `Customers.EPON`. |
| Appointment log | `Appointments2_Log` | 23,967 | Preserve as audit/history staging; do not create duplicate appointments from log rows. |
| Appointment categories | `AppointmentCategories` | 12 | Preserve names and descriptions. |
| Appointment labels | `AppointmentsEtiketa` | 9 | Preserve order and colour. |
| Appointment auxiliary colours/types | `AppointmentsORA` | 4 | Exact UI meaning requires confirmation. |
| Patient images/files | `CustomerImages` | 769 | All rows match a patient GUID. |
| Radiography forms/images | `Aktinografies2` | 179 | 173 match a patient GUID; 6 require review. |
| Stored file-path references | `CustomerImages` | 1,491 | 1,354 referenced basenames are present in the copied folder; remaining references need reconciliation. |
| Patient memos | `CustomerMemos` | 321 | All rows match a patient GUID. |
| Recalls | `RECALLS` | 78 | All rows match a patient GUID. |
| Financial movements | `kinisi` | 1,257 | 1,122 have a numeric `ID2` collision with `Customers.id`, but the finance pilot proved that this is not a validated patient link. All rows require movement-type and source-role reconciliation. |
| Work payments | `WorkPliromes` | 2 | Both match a patient GUID. |

The supplied folder also contains many ordinary images and documents. File counts alone are not treated as patient links; database metadata and reconciliation determine ownership.

## 4. Corrected DentalWin identity map

The supplied copy resolves an important ambiguity in the earlier master specification.

### 4.1 Patient identifiers

| Source field | Verified use | Target handling |
|---|---|---|
| `Customers.id` | Unique numeric patient ID; used by main clinical work and other numeric-link tables | Preserve as an external identifier. Never reuse it as the Apexo internal ID. |
| `Customers.EPON` | Unique 36-character DentalWin patient identifier; all contacts and main clinical work link to it | Preserve as the primary DentalWin patient GUID external identifier. |
| `Customers.guidss_astheni` | Secondary 36-character field, populated for only part of the patient set | Preserve as an additional source identifier when nonblank; do not replace `EPON`. |
| `Customers.guidss_private` | Blank in this copy | Preserve only if a future source copy contains a value. |
| `Customers.ar_mitroou` | DentalWin registration-number candidate | Preserve as a legacy registration number. Apexo still generates its own authoritative registration number. |
| `Customers.aa_number`, `Customers.LST` | Legacy folder/sequence candidates | Preserve independently until their display meanings are confirmed. |

### 4.2 Never merge patients by name automatically

The patient import key is the source database fingerprint plus `Customers.id`. `Customers.EPON` is a second stable identity check.

Names, contacts, AMKA, AFM, birth details, and folder numbers are used to **suggest** possible duplicates between DentalWin and an already-populated Apexo database. A suggested duplicate must be approved by a human. A matching name alone must never cause an automatic merge.

## 5. Migration architecture

### 5.1 Three separate layers

The migration uses three layers so that raw history is not confused with the final clinical record.

1. **Read-only extractor**
   - opens the copied Access databases read-only;
   - calculates source fingerprints and row counts;
   - emits no patient values to the console;
   - never imports directly into Apexo.

2. **Local staging database**
   - stores source keys, protected raw values, normalized candidate values, mapping version, and validation results;
   - lives outside Git and outside ordinary application data;
   - may be deleted and rebuilt from the unchanged source copy;
   - is the only place where uncertain mappings are transformed and reviewed.

3. **Apexo import adapter**
   - consumes only an approved staged batch;
   - creates normal Apexo domain records and provenance records;
   - writes in bounded, resumable batches;
   - verifies each batch before continuing;
   - supports a safe repeat run without duplicates.

### 5.2 Current Apexo compatibility

Current Apexo stores patients, appointments, notes, and expenses as JSON documents in a shared PocketBase `data` collection, separated by a `store` value. The current patient and appointment models are too compressed for a faithful DentalWin migration:

- patient contacts are currently embedded in the patient JSON prototype;
- procedures, treatment plans, clinical events, and ledger entries do not yet have dedicated models;
- tooth data is a map of whole-tooth labels rather than versioned tooth/surface events;
- appointment `price` and `paid` combine clinical scheduling and finance;
- files are normally attached to appointment rows rather than first-class patient documents.

The migration must therefore introduce new logical stores/models before importing treatments, plans, files, or finance. Importing everything into current appointment fields would lose meaning and is not approved.

## 6. Target logical entities

The target names below describe logical entities. Their final Dart class/store names may follow Apexo naming conventions during implementation.

| Target entity | Purpose |
|---|---|
| `migration_batches` | Source fingerprints, mapping version, timestamps, mode, approval, and batch result. |
| `external_identifiers` | Stable DentalWin database/table/row identifiers attached to every imported target record. |
| `migration_review_items` | Unmatched, ambiguous, invalid, quarantined, or owner-decision records. |
| `patients` | Authoritative Apexo patient identity and demographics, following the approved patient-fields blueprint. |
| `patient_contacts` | Any number of typed telephone, mobile, email, or unknown contact values. |
| `medical_history_revisions` | Immutable imported or patient-confirmed medical-history snapshots. |
| `clinical_alerts` | Visible alerts with source, review state, author, and timestamps. |
| `therapy_groups` | Owner-configurable procedure groups, display order, colour, and active/hidden state. |
| `procedure_catalog` | Owner-configurable dental works, prices, tooth requirements, duration, display behaviour, and legacy codes. |
| `treatment_plans` | Versioned patient treatment plans. |
| `treatment_plan_items` | Proposed/accepted/rejected/completed/cancelled plan entries linked to teeth/surfaces and procedures. |
| `clinical_events` | Historical or newly completed work, with original text, date, tooth, notes, and clinician links. |
| `odontogram_events` | Versioned tooth/surface conditions and treatments; never just the current painted state. |
| `appointments` | Scheduling records with start, end, patient, staff/resource, category, label, status, and notes. |
| `appointment_audit_events` | Selected imported appointment-log history and future Apexo audit events. |
| `patient_documents` | Images, radiographs, PDFs, scans, consent images, and other patient files with metadata. |
| `patient_notes` | Dated patient/clinical notes that are not treatment events. |
| `recalls` | Recall due dates, completion state, notes, and patient links. |
| `ledger_entries` | Charges, payments, credits, adjustments, and opening balances linked to clinical events where known. |

## 7. Domain mappings

### 7.1 Patients

The complete personal-field map is defined in the approved [Patient Fields Blueprint](PATIENT_FIELDS_BLUEPRINT.md). The migration-specific rules are:

- `Customers.NAME` -> `surname`;
- `Customers.LAST` -> `first_name`;
- `Customers.id` and `Customers.EPON` -> external identifiers;
- `Customers.ar_mitroou` -> legacy registration number, not the new Apexo-generated registration number;
- unknown or empty source values stay empty;
- an invalid or unsplittable name is preserved in `legacy_full_name` and enters review;
- imported records are allowed even when they do not satisfy new-patient form requirements;
- archive/active state is mapped only after the source value meaning is verified;
- balances, consent images, medical warnings, documents, and family relationships are not flattened into general patient notes.

### 7.2 Contacts

`CustomerEpikoinonies` is the authoritative contact-row source.

| DentalWin value | Target contact type |
|---|---|
| `typos = 0` | Home telephone |
| `typos = 1` | Work telephone |
| `typos = 2` | Mobile telephone |
| `typos = 4` | Email |
| any other value | `other`, with original type retained and a review/report entry |

For every contact:

- preserve `epikoinonia` exactly as `raw_value`;
- calculate a separate normalized search value;
- preserve `sms_contact` as `true`, `false`, or unknown according to verified encoding;
- preserve `memos` as contact notes;
- never replace structured contact rows with the cached contact lists in `Customers`;
- use cached lists only for reconciliation and possible recovery of a missing contact row.

### 7.3 Medical history

`DentalSchoolIstoriko` contains 813 historical forms. Each imported form becomes an immutable `medical_history_revision` with `source = DentalWin`.

Verified text and flag mappings from the master specification remain valid only where the final-copy column exists. Examples include:

- reason for visit and present condition;
- legacy medicines text;
- diseases/surgeries and general notes;
- hypertension and cardiovascular history;
- penicillin and latex allergy;
- other explicit yes/no fields whose encoding is verified by a source-value audit.

Rules:

- preserve the original free text;
- do not turn free text into a definite diagnosis or medication automatically;
- imported positive high-risk fields may create a visible **legacy/unconfirmed** alert;
- the alert remains visibly unconfirmed until staff review;
- the 2 history rows without a patient match enter review and are not dropped;
- other small legacy history tables are staged separately until their relationship and meaning are proven.

### 7.4 Therapy groups

`Works_Kategories` becomes owner-configurable `therapy_groups`.

Preserve:

- `guidss`, `id`, and other stable source identifiers;
- Greek category name;
- display order;
- hidden/active state;
- process/imaging flags as legacy metadata until their meaning is confirmed;
- source timestamps and editor values as provenance where useful.

Verified group snapshot:

| Order/ID | DentalWin group | Works | Initial target decision |
|---:|---|---:|---|
| 1 | Οδον. Χειρουργική 1 | 25 | Import active. |
| 13 | Οδοντ. Χειρουργική 2 | 19 | Import active; owner may later rename or merge, never merge during migration. |
| 2 | Ενδοδοντία | 23 | Import active. |
| 4 | Εξακτική/Χειρουργική | 23 | Import active. |
| 5 | Ακίνητη Προσθετική | 50 | Import active. |
| 7 | Κινητή Προσθετική | 33 | Import active. |
| 10 | Ορθοδοντική | 3 | Import active. |
| 9 | Περιοδοντολογία | 24 | Import active. |
| 11 | Εμφυτεύματα | 13 | Import active. |
| 12 | Πρόληψη | 11 | Import active. |
| 3 | Διάγνωση | 41 | Import active. |
| 14 | Παιδοδοντία | 4 | Import active. |
| 15 | Γενικά | 7 | Import hidden; owner can activate later. |
| 16 | `DF260629_CATEGORIES` | 0 | Quarantine as a probable placeholder; do not show in the live menu without owner approval. |

Three dental works currently have no valid category. They enter an `Uncategorized legacy works` review group rather than disappearing.

### 7.5 Procedure catalogue

`WooksTools` becomes `procedure_catalog`.

Preserve at minimum:

- source GUID, numeric ID, and stable `id_code`;
- work name `frst` and any alternative names;
- therapy-group link `katigoria`;
- display order and hidden state;
- base and alternate price fields as separately labeled legacy prices;
- per-tooth pricing flag;
- tooth-required setting;
- duration when present;
- laboratory/technician/material/VAT metadata where meaningful;
- symbol, line, image, and render-position metadata as legacy rendering configuration;
- process, imaging, and print flags.

Important limitations:

- only 132 of 279 works have a nonzero base price;
- only 1 work contains a positive duration, so default durations must be configured later rather than invented;
- tooth requirement is explicitly true for 73 works, explicitly false for 49, and unset for 157;
- the old `mdft1`/`mdft2` surface fields are blank in this copy;
- old render image names are not direct matches to copied file basenames and may refer to embedded or legacy resources;
- DentalWin contains 33 render behaviour definitions, but the exact catalogue-field link to those definitions is not yet proven.

The owner must be able to add, rename, hide, reorder, recolour, and price therapy groups and procedures after migration without changing historical records.

Historical clinical events keep a snapshot of the name and price that existed at the time. Renaming a current catalogue item must not rewrite history.

### 7.6 Performed work and treatment plans

`WorksPelati` is the main historical clinical-work source.

Map:

| DentalWin field | Target |
|---|---|
| `id`, `guidss` | External identifiers for the source work row |
| `kodikosPelati`, `guidsspelati` | Patient link checks |
| `hmerominia` | Clinical-event or plan-item date |
| `ergasia` | Immutable original work-name snapshot |
| `id_code_work` | Procedure-catalogue link when it matches a stable catalogue code |
| `katigoria` | Legacy therapy-group value; verify against the linked catalogue item |
| `donti` | Raw tooth value plus parsed FDI tooth reference where valid |
| `memos`, `memos_2` | Clinical notes, kept distinct and source-labeled |
| `SxedioUerapias` | Treatment-plan membership flag |
| `status`, `pay_status`, `akirosi` | Raw legacy statuses until their UI meaning is confirmed |
| `appointment_id` | Candidate link to an appointment; verify before linking |
| `IDDOCTORS`, technician fields | Candidate clinician/technician links; preserve raw when unresolved |
| `xreosi`, `pistosi`, `sinolo`, discounts, VAT and cost fields | Staged financial values, not automatically authoritative ledger entries |

Catalogue matching result:

- 8,110 work rows match a current catalogue item by stable `id_code_work`;
- 1 additional row can match a unique exact catalogue name;
- 2,961 rows have no catalogue match and become `legacy/custom` clinical events while preserving their original names;
- none of the 11,072 rows is dropped because of a missing catalogue match.

Tooth handling:

- a valid single FDI code becomes a whole-tooth link;
- `00` or blank is treated as general/no specific tooth, not as tooth zero;
- primary-tooth codes are retained;
- delimited or invalid values preserve their raw text and enter review;
- no mesial, distal, buccal, lingual/palatal, or occlusal surface is invented for old work.

Treatment-plan handling:

- the 91 rows with `SxedioUerapias = 1` become imported plan items;
- they belong to an imported legacy plan per patient unless a reliable plan/version relation is discovered;
- plan status is `legacy_unknown` until DentalWin’s status controls are confirmed;
- a plan item may later be linked to a completed event, but the importer must not assume that merely from matching text and tooth.

`WorksPelatiD` and `WorksPelatiU` are extracted into staging with all identifiers and relationships. They are not merged into the main clinical timeline until their deleted/updated/history semantics are proven from DentalWin UI evidence and relationship analysis.

### 7.7 Odontogram

DentalWin’s dedicated `odontogrammata` and `CustomerToothState` tables are empty in this copy. The historical work table contains whole-tooth FDI references but no reliable named surface data.

Therefore:

- historical work is shown as whole-tooth clinical history;
- primary-dentition rows from `NeogilaDontiaPelati` are preserved;
- the new Apexo surface-selection model is new functionality for future charting;
- old records must not be visually painted onto a particular surface without evidence;
- the current Apexo `Map<tooth, label>` structure is not sufficient for the final model;
- the future odontogram uses versioned events linked to patient, tooth, optional surface set, procedure/condition, plan item, completed event, appointment, and documents.

The imported history will remain clinically useful even before the new odontogram artwork is complete.

### 7.8 Appointments

`Appointments2` becomes the appointment source. Core mappings:

| DentalWin field | Target |
|---|---|
| `guidss`, `id` | External appointment identifiers |
| `guidsspelati` | Patient link through `Customers.EPON` |
| `Subject` | Original appointment title snapshot |
| `Description` | Internal appointment notes |
| `StartTime` | Start date/time |
| `EndTime` | End date/time; duration is derived and both are retained logically |
| `AllDay`, recurrence and reminder fields | Appointment timing metadata |
| `Status`, `katastasi`, `gen_status` | Raw statuses until their meanings are confirmed |
| `Label` | Appointment label/colour relation |
| `Price` | Legacy appointment price, not automatically a final ledger charge |
| `ContactInfo` | Legacy snapshot; not a replacement for patient contacts |
| `guidss_google` | Preserved Google Calendar external identifier |
| `OutlookEntryID` | Preserved Outlook external identifier |
| `work_data` | Staged legacy work payload pending format interpretation |
| SMS fields | Preserved messaging state/text subject to privacy review |

Patient linking:

- 1,801 appointments contain a patient GUID and all 1,801 match `Customers.EPON`; these are deterministic links;
- exact unique patient-name comparison suggests 497 additional candidates, but a name-only match is not deterministic and requires review;
- 1,955 appointments remain unresolved after GUID plus exact-unique-name candidate analysis;
- unresolved appointments are imported into a protected review queue or preserved as unlinked legacy appointments, never dropped;
- further matching may use contact snapshots and other evidence, but no fuzzy match is accepted silently.

`Appointments2_Log` is an appointment audit source. Its 23,967 rows do not become new appointments. The extractor groups them by original appointment identifier and stages action, timestamp, actor, comments, and changed values for possible import as audit history.

Appointment categories and labels retain their DentalWin names, order, descriptions, and colours. Therapy-group colour and appointment-label colour remain separate concepts unless the owner explicitly maps them.

### 7.9 Images, radiographs, documents, and consent material

`CustomerImages` and `Aktinografies2` become `patient_documents` with source-specific metadata.

For each document:

- preserve source row identifiers, patient link, title, description, dates, group/exam identifiers, X-ray kind, original path text, and import checksum;
- copy the file into Apexo-managed storage without modifying the source file;
- calculate a content hash and deduplicate only the binary storage, never the distinct clinical metadata rows;
- preserve whether a file was missing, unreadable, duplicated, embedded, or recovered from an alternate path;
- never infer the patient owner from a folder name when a database link conflicts;
- quarantine the 6 radiography rows whose patient GUID does not match the patient table;
- reconcile the 137 currently unmatched path references before declaring any source file missing;
- keep embedded radiography/image blobs available for extraction when no external file is present.

`Customers.eikona`, `GDPRImage`, `importantInfo`, and any signature/consent-like fields are quarantined by field and patient. Their binary/text format and legal meaning must be inspected before they are shown as a portrait, consent, signature, or clinical alert.

### 7.10 Patient notes and recalls

- `CustomerMemos` becomes dated, source-labeled patient notes while preserving RTF/plain-text format information.
- `RECALLS` becomes recall records with raw status, completion date, notes, SMS flag, clinic identifiers, and patient link.
- a recall is not converted into an appointment unless the source explicitly links one or a user performs the conversion.
- legacy note types that cannot be classified remain `legacy_unknown`, not general administrative notes by default.

### 7.11 Finance

DentalWin finance is staged separately from the clinical timeline.

Sources include:

- charge/payment fields within `WorksPelati`;
- `WorkPliromes` payment rows;
- `kinisi` financial movements;
- patient-level balance and discount fields in `Customers`.

Rules:

1. Preserve all original monetary fields and currency assumptions as source metadata.
2. Do not create both a work-derived payment and a `WorkPliromes` payment if they represent the same event.
3. Do not treat `kinisi` as authoritative until debit/credit signs, income/expense categories, taxes, cancellations, invoices, and patient links are reconciled.
4. A numeric `kinisi.ID2 -> Customers.id` equality must **not** create a patient link. The finance pilot found clinic-expense rows whose `ID2` merely collided with pilot patient IDs.
5. All 1,257 movements therefore remain preserved in finance staging and review; none are approved patient-ledger entries from `ID2` alone.
6. Imported clinical work may be visible before imported finance is approved.
7. The target ledger keeps immutable entries and corrections/reversals rather than rewriting historical money.
8. Per-patient and global source totals must be compared with staged and target totals.
9. Any discrepancy blocks finance cutover but does not block a validated patient/clinical-history import.

## 8. Provenance and idempotency

Every imported target record receives an external-identifier entry containing:

- source system: `DentalWin`;
- source database fingerprint;
- source database role;
- source table;
- source primary key or deterministic composite key;
- source patient numeric ID and/or `EPON` when relevant;
- source row hash;
- mapping version;
- migration batch ID;
- import timestamp;
- target entity type and target ID;
- result status and any review-item ID.

The uniqueness rule is:

`source_database_fingerprint + source_table + source_record_key + target_entity_type`

A repeated run with the same mapping version must not create a duplicate. A source row changed after an earlier test run is reported as changed and requires an explicit update policy.

## 9. Review queues

Review items use a reason code, severity, source reference, suggested action, decision, reviewer, and timestamp.

Initial reason codes include:

- `possible_existing_patient_duplicate`;
- `patient_name_missing_or_unsplittable`;
- `unknown_contact_type`;
- `invalid_contact_value`;
- `orphan_medical_history`;
- `unmatched_catalog_work`;
- `uncategorized_catalog_work`;
- `unknown_work_status`;
- `ambiguous_or_invalid_tooth`;
- `unresolved_secondary_work_row`;
- `appointment_patient_missing`;
- `appointment_name_match_candidate`;
- `appointment_status_unknown`;
- `document_file_not_found`;
- `document_patient_missing`;
- `consent_or_signature_format_unknown`;
- `financial_patient_missing`;
- `financial_semantics_unverified`;
- `source_row_error`.

Review decisions are themselves audited. A later rerun reuses approved decisions where the source row hash has not changed.

## 10. Validation and reconciliation

### 10.1 Row accounting

For every source table:

`source rows = created + linked + already imported + review required + approved exclusions + errors`

The report shows the equation and fails if it does not balance.

### 10.2 Relationship checks

- every imported contact has a patient;
- every imported medical-history revision has a patient or review item;
- every imported clinical event has a patient;
- every imported plan item has a patient and plan;
- every imported document has a patient or quarantine item;
- every deterministic appointment patient link uses a stable identifier;
- every imported catalogue work has a therapy group or the explicit legacy uncategorized group;
- every external identifier points to exactly one target record of its type.

### 10.3 Content checks

- Greek text round-trips without replacement characters;
- leading zeroes in identifiers and postal codes remain intact;
- exact dates remain exact and partial/invalid dates remain labeled as such;
- raw contact, tooth, treatment, note, and financial values remain recoverable;
- start and end appointment times produce a nonnegative duration or a review item;
- file hashes before and after copying match;
- no real patient values appear in console output or ordinary diagnostic logs.

### 10.4 Count expectations for the current copy

The first full dry run must account for at least:

- 1,129 patients;
- 2,113 contacts;
- 813 medical-history rows;
- 14 therapy groups;
- 279 catalogue works;
- 11,072 main clinical-work rows;
- 91 treatment-plan rows within that work set;
- 4,253 appointments;
- 769 patient-image rows;
- 179 radiography rows;
- 321 memos;
- 78 recalls;
- 1,257 financial movements;
- 2 work-payment rows.

Secondary and audit tables receive their own separate reconciliation sections.

## 11. Dry-run deliverables

Before any Apexo write, the importer produces:

1. a source fingerprint manifest;
2. schema and row-count inventory;
3. human-readable HTML or Markdown summary containing counts only;
4. machine-readable JSON summary containing counts and reason codes only;
5. patient duplicate-candidate count, without patient details in the general report;
6. therapy-group and catalogue mapping report;
7. treatment/catalogue/tooth parsing report;
8. appointment patient-link report;
9. document existence/hash reconciliation report;
10. finance reconciliation report;
11. protected row-level review file available only to the authorized migration operator;
12. a statement that DentalWin source fingerprints are unchanged after extraction.

## 12. Import order

The approved test import should occur in this order:

1. migration batch and provenance infrastructure;
2. therapy groups and procedure catalogue;
3. patients and patient contacts;
4. medical-history revisions and legacy alerts;
5. treatment plans and main clinical events;
6. primary-tooth and whole-tooth historical references;
7. patient notes and recalls;
8. appointments, categories, labels, and selected audit history;
9. patient documents and radiographs;
10. finance only after its separate reconciliation is approved;
11. unresolved secondary tables only after their semantics are proven.

Clinical and financial import checkpoints are separate. A failed finance approval must not require discarding a successful validated patient and clinical-history test import.

## 13. Rollback and recovery

Before a test or production import:

- create an Apexo/PocketBase database backup;
- include the PocketBase file storage directory;
- record backup checksums;
- verify that the backup can be opened or restored in an isolated environment;
- stop normal clinic writes during the final cutover window.

Rollback consists of restoring the complete pre-import PocketBase database and file storage together. Deleting only imported database rows is not an adequate rollback because uploaded files and cross-record links may remain.

The DentalWin copy remains unchanged and can rebuild staging from the beginning.

## 14. Implementation phases

### Phase 1 — Approved blueprint

- owner reviews this document;
- uncertain meanings and exclusions are recorded;
- no patient data is written to Apexo.

### Phase 2 — Read-only extractor and synthetic tests

- implement Access readers behind a read-only interface;
- create synthetic Access fixtures containing no real patient information;
- implement source fingerprints, row keys, staging schema, and aggregate reports;
- verify that opening/extracting does not change source hashes.

### Phase 3 — Full private dry run

- extract the supplied copy into private staging;
- generate aggregate reports and protected review queues;
- reconcile every source table;
- make no Apexo writes.

### Phase 4 — Empty test-server import

- restore a separate test PocketBase instance;
- import an approved staged batch;
- verify counts, links, search, Greek text, patient panels, calendar, images, and Android read access;
- repeat the same import and prove that no duplicates appear.

### Phase 5 — Owner review and corrections

- review representative patients inside the software;
- review catalogue groups and prices;
- review treatment history and plans;
- resolve appointment and document queues;
- decide whether finance is ready.

### Phase 6 — Production cutover

- take and verify a new backup;
- fingerprint the final DentalWin copy;
- rerun dry-run reconciliation;
- obtain explicit owner approval;
- import in checkpoints;
- verify Windows/web and Android views;
- retain reports and rollback instructions.

## 15. Decisions still needed from the owner

The blueprint can be approved before these are all answered, but the affected domain cannot be imported as final until its decision is recorded.

1. Meaning of `WorksPelati.status`, `pay_status`, `akirosi`, and the visible DentalWin treatment-state controls.
2. Meaning and lifecycle of `WorksPelatiD` and `WorksPelatiU`.
3. Whether the hidden `Γενικά` category should remain hidden and whether the empty placeholder category should be excluded.
4. Whether the three uncategorized works should enter a visible `Legacy uncategorized` group.
5. Meaning of DentalWin’s 33 render types and how each catalogue work chooses one.
6. Whether imported plan rows should appear in one legacy plan per patient or be grouped by another verified rule.
7. Appointment status/label/category meanings, including `AppointmentsORA`.
8. Whether name-only appointment candidates may be bulk-approved after a review report or must be approved one by one.
9. Format and intended use of `GDPRImage`, `importantInfo`, portraits, and any consent/signature fields.
10. Exact debit/credit and cancellation rules for `kinisi`, `WorksPelati`, and `WorkPliromes`.
11. How much historical finance should become an active ledger versus a read-only legacy financial statement.
12. Role permissions for protected identifiers, medical history, documents, and finance.

Useful screenshots for these decisions are:

- the DentalWin therapy-group and dental-work editor;
- a dental-work configuration window showing price, tooth requirement, display/render behaviour, and stages;
- treatment-plan and completed-work screens showing statuses and colours;
- appointment category/label/status editors;
- a patient financial-history screen showing charges, payments, reversals, and balance.

Screenshots are supporting evidence only. The database remains the migration source.

## 16. Approval gate

The owner subsequently approved Phase 3 on 2026-08-26. That approval authorized only the full private read-only dry run: encrypted staging, protected review queues, and aggregate reconciliation reports. Phase 3 completed without writing to Apexo.

The next gate is Phase 4. It requires separate owner approval before creating or writing to an isolated empty test PocketBase server.

It does **not** authorize:

- writing to DentalWin;
- importing into the production Apexo server;
- merging a DentalWin patient with an existing Apexo patient;
- activating unconfirmed medical alerts as verified diagnoses;
- assigning old work to invented tooth surfaces;
- treating unreconciled financial values as authoritative;
- deleting or excluding unresolved source records.
