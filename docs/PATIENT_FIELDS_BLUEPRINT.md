# Patient Fields Blueprint

Status: Approved by owner

Date: 2026-08-25

Scope: Patient identity, personal details, contacts, administrative details, and DentalWin provenance

## 1. Purpose

This blueprint defines the patient information that the Apexo fork must be able to preserve. It combines:

- the personal-information fields visible in DentalWin;
- only section A, `ΠΡΟΣΩΠΙΚΑ ΣΤΟΙΧΕΙΑ`, from `ΙΣΤΟΡΙΚΟ 5.pdf`;
- confirmed DentalWin database mappings from the master specification;
- the fields already supported by Apexo.

The goal is to preserve the clinic's existing information without forcing every field to appear on every screen. A field may be hidden from normal use while remaining stored, searchable when appropriate, and available to resurface later.

This document is a design blueprint. It does not import patient data and does not change the application or database.

## 2. Owner direction already confirmed

The following decisions were confirmed by the owner on 2026-08-25:

1. The target should cover the useful personal-information fields already available in DentalWin.
2. DentalWin fields should remain available even when the clinic later hides them from the everyday interface.
3. The paper form contributes only its `ΠΡΟΣΩΠΙΚΑ ΣΤΟΙΧΕΙΑ` section to this blueprint.
4. The DentalWin screenshots and paper fields should be united into one target model suitable for automatic migration and tablet intake.
5. Exact source-column mappings may be proposed from verified evidence, but unknown DentalWin columns must not be guessed.
6. Surname and first name are the only fields that are always required for every new patient.
7. A patient registration number is generated automatically; staff and patients do not type it.
8. A tablet intake submission requires at least one mobile number, telephone number, or email address.

## 3. Required-field policy

There is a difference between a field being **supported** and being **required**.

### 3.1 Approved default for a patient created by staff

- `surname`: required;
- `first_name`: required;
- a telephone number, mobile number, or email: recommended, but not required for staff entry;
- every other field: optional.

AMKA, AFM, email, address, contact details, and date of birth must not be universally mandatory because legitimate patients and legacy records may not have them.

### 3.2 Approved default for tablet intake

A tablet intake submission requires:

- `surname`;
- `first_name`;
- at least one contact value classified as mobile telephone, other telephone, or email.

The form may accept several contacts. Empty spaces and an invalid telephone number or email do not satisfy the requirement. The patient registration number is generated only after the submission is accepted into the authoritative patient registry.

### 3.3 Imported and exceptional records

An imported patient must not be discarded merely because a modern required field is missing. Such a record may use `legacy_full_name`, must retain its DentalWin identity, and should enter a review queue when its name cannot be separated reliably.

### 3.4 No invented defaults

Unknown information must remain unknown.

- Do not convert an unknown date of birth into January 1 of an arbitrary year.
- Do not assume a sex/gender value when the source is blank.
- Do not insert a fake email, telephone number, AMKA, AFM, or address.
- Do not use the import date as the historical registration date.

This replaces Apexo's current behavior of defaulting a new patient to an 18-year-old birth year and a binary gender value.

## 4. Target logical entities

The target model consists of related records rather than one oversized patient form.

### 4.1 `patients`

Stores identity, demographics, address, clinic administration, display preferences, and archive state.

### 4.2 `patient_contacts`

Stores any number of home phones, work phones, mobile phones, emails, and future contact types. Each contact retains its original imported value and a separate normalized value.

### 4.3 `external_identifiers`

Stores DentalWin IDs, GUIDs, folder numbers, and future source-system identifiers. These records make imports traceable and repeatable.

### 4.4 `patient_relationships`

Represents family links and other patient-to-patient relationships when DentalWin relationship data is understood. A free-text family label may be preserved temporarily without inventing a relationship.

### 4.5 Related but separate records

The following information may appear on a DentalWin patient screen, but it should not be stored as a basic personal field:

- balances and discounts belong to the ledger;
- last-visit date and age are derived values;
- health warnings belong to versioned medical alerts;
- treating clinicians belong to patient-clinician relationships;
- referrals made to another clinician belong to referral records;
- photographs and scanned identity/consent documents belong to protected documents;
- signatures and possible `GDPRImage` content belong to consent/document records after their meaning is verified.

The information remains available without copying DentalWin's screen layout directly into one database row.

## 5. Patient field catalog

Legend for source confidence:

- **Confirmed**: a working DentalWin database column mapping was previously verified.
- **Working/verify**: the mapping is plausible and must be checked against the actual database.
- **Screenshot only**: the field is visible in DentalWin, but its source column is not yet known.
- **Paper form**: present in section A of the paper form.
- **Apexo existing**: supported in the current Apexo patient JSON.

### 5.1 Identity and demographics

| Target field | Type | Required | Default visibility | Sources and mapping | Notes |
|---|---|---:|---|---|---|
| `id` | immutable text ID | automatic | system | Apexo existing | Keep the existing 15-character Apexo ID format if adequate. Never reuse an ID. |
| `registration_number` | server-generated unique text/number | automatic | summary/administrative | new target field | Generated when a patient is accepted into the registry. It is a human-facing clinic reference, not the database primary key. Imported DentalWin folder numbers remain separate legacy identifiers. |
| `surname` | text | yes for new staff entry | summary | DentalWin `Customers.NAME` - **Confirmed** | The DentalWin column name is counterintuitive: `NAME` means surname. |
| `first_name` | text | yes for new staff entry | summary | DentalWin `Customers.LAST` - **Confirmed** | The DentalWin column name is counterintuitive: `LAST` means first name. |
| `legacy_full_name` | text | conditional import fallback | additional | Apexo `title`; paper `ΟΝΟΜΑΤΕΠΩΝΥΜΟ` | Preserve an unsplit name when separation is uncertain. It must not overwrite confidently split names. |
| `display_name` | derived text | automatic | summary | derived | Prefer surname and first name; fall back to `legacy_full_name`. Do not maintain a conflicting second editable name. |
| `patronymic` | text | no | additional | DentalWin `Customers.politis` - **Confirmed**; screenshot `Όνομα Πατέρα` | Preserve source spelling. |
| `mother_name` | text | no | additional | DentalWin screenshot `Όνομα Μητέρας` - **Screenshot only** | Exact database column requires verification. |
| `birth_date` | date | no | summary | paper `ΗΜΕΡ.ΓΕΝ.`; DentalWin screenshot `Ημ. Γέννησης` - **Screenshot only** | Store an exact date only when the source is exact. |
| `approximate_birth_year` | integer year | no | summary | Apexo `birth` - **Apexo existing** | Used when only a year is known. |
| `birth_date_precision` | enum: `exact`, `year_only`, `unknown` | automatic | system | derived from source | Prevents a guessed full date from looking exact. |
| `sex_or_gender` | enum including `unknown` | no | summary | Apexo `gender`; DentalWin male/female controls - **Apexo existing / Screenshot only** | Exact labels and whether an `other` value is required remain an owner decision. Blank must map to `unknown`. |
| `occupation` | text | no | summary | DentalWin `Customers.EPPAGGELMA` - **Confirmed**; paper `ΕΠΑΓΓΕΛΜΑ` | Do not force a catalog value; preserve free text. |
| `secondary_occupation_label` | text | no | legacy/additional | DentalWin screenshot label `Επάγγελμα Μ` - **Screenshot only** | The meaning of the abbreviated label must be verified before assigning a clinical name such as mother's or spouse's occupation. |
| `place_of_origin_or_birth` | text | no | additional | DentalWin screenshot `Τόπος καταγωγής` - **Screenshot only** | Preserve the original label until its intended meaning is confirmed. |
| `registration_date` | date | no | administrative | DentalWin screenshot `Ημ. Εγγραφής` - **Screenshot only** | The actual source column is unresolved. Keep import/cutover date separately. |
| `active_status` | enum: `active`, `inactive`, `archived` | automatic | administrative | Apexo `archived`; DentalWin `Ενεργός` - **Apexo existing / Screenshot only** | Archive remains reversible. No ordinary hard delete. |

### 5.2 Address

| Target field | Type | Required | Default visibility | Sources and mapping | Notes |
|---|---|---:|---|---|---|
| `address_line` | text | no | summary | DentalWin `Customers.PEDIO2` - **Confirmed**; paper `ΔΙΕΥΘΥΝΣΗ`; Apexo `address` | Preserve imported punctuation and casing. |
| `area` | text | no | additional | DentalWin `Customers.PEDIO4` - **Confirmed** | Kept separately from city. |
| `city` | text | no | summary | DentalWin `Customers.PEDIO3` - **Confirmed** | Searchable after Greek normalization. |
| `postal_code` | text | no | summary | DentalWin `Customers.PEDIO5` - **Confirmed**; paper `ΤΑΧ.ΚΩΔΙΚΑΣ` | Text, never numeric, so leading zeroes are preserved. |
| `country_code` | ISO country code or null | no | additional | new target field | Useful for telephone and address normalization; do not infer silently when uncertain. |

### 5.3 Official and clinic-administration fields

| Target field | Type | Required | Default visibility | Sources and mapping | Notes |
|---|---|---:|---|---|---|
| `amka` | text | no | protected administrative | paper `ΑΜΚΑ`; DentalWin screenshot - **Screenshot only** | Preserve leading zeroes. Exact source column must be verified. |
| `afm` | text | no | protected administrative | DentalWin `Customers.afm` - **Confirmed**; paper `ΑΦΜ/ΔΟΥ` | Store separately from DOY. Preserve leading zeroes. |
| `doy` | text | no | protected administrative | DentalWin `Customers.doy` - **Confirmed**; paper `ΑΦΜ/ΔΟΥ` | Do not combine with AFM in storage. |
| `identity_card_number` | text | no | protected administrative | DentalWin screenshot `ΑΔΤ` - **Screenshot only** | Exact source column requires verification. |
| `identity_issue_details` | text | no | protected administrative | DentalWin screenshot `Έκδοση` - **Screenshot only** | Meaning and database column require verification. |
| `insurance` | text or future relation | no | administrative | DentalWin screenshot `Ασφάλιση` - **Screenshot only** | Start by preserving text; normalize only after source values are inspected. |
| `patient_category` | text or future catalog relation | no | administrative | DentalWin screenshot `Κατηγορία` - **Screenshot only** | Preserve unknown values rather than discarding them. |
| `financial_category` | text or future catalog relation | no | finance-restricted | DentalWin screenshot `Οικ. Κατηγορία` - **Screenshot only** | Separate from the general patient category. |
| `salutation_1` | text | no | additional | DentalWin screenshot `Προσφώνηση 1` - **Screenshot only** | Exact use requires owner/source review. |
| `salutation_2` | text | no | additional | DentalWin screenshot `Προσφώνηση 2` - **Screenshot only** | Exact use requires owner/source review. |
| `referral_source` | text or future relation | no | administrative | DentalWin screenshot `Σύσταση από` - **Screenshot only** | Paper-form referral choices are outside section A and are intentionally not used in this blueprint. |
| `administrative_notes` | multiline text | no | administrative | Apexo `notes`; DentalWin auxiliary fields - **Apexo existing / Screenshot only** | Must remain distinct from clinical notes and medical history. |
| `tags` | list of text | no | summary/additional | Apexo `tags` - **Apexo existing** | Useful for clinic workflow; not a substitute for structured medical alerts. |

### 5.4 Contact records

Each contact is a separate `patient_contacts` record.

| Contact field | Type | Required | Source | Notes |
|---|---|---:|---|---|
| `id` | immutable text ID | automatic | target | One ID per contact row. |
| `patient_id` | relation | yes | target | Links the contact to one patient. |
| `type` | enum | yes | DentalWin `CustomerEpikoinonies.typos` - **Confirmed** | `0` home phone, `1` work phone, `2` mobile, `4` email. Undocumented types are preserved and reported. |
| `label` | text | no | DentalWin contact type/display | Allows custom descriptions without losing the normalized type. |
| `raw_value` | text | yes | `CustomerEpikoinonies.epikoinonia` - **Confirmed** | Exact imported source value; never overwritten by normalization. |
| `normalized_value` | text | automatic when possible | derived | Used for search and duplicate detection. |
| `is_primary` | boolean | automatic/reviewable | target | A documented rule may suggest a primary contact; staff can change it. |
| `sms_allowed` | boolean or unknown | no | DentalWin contact-grid SMS checkbox - **Screenshot only** | Unknown is different from denied. Exact source column requires verification. |
| `notes` | text | no | DentalWin contact-grid notes - **Screenshot only** | Exact source column requires verification. |
| `source_provenance` | relation/metadata | automatic on import | target | Links back to source table, record, and batch. |

The paper fields `ΤΗΛΕΦΩΝΟ`, `ΚΙΝΗΤΟ`, and `E-MAIL` map to contact records, not fixed columns on `patients`.

### 5.5 External identifiers and provenance

| Target field | Type | Required for imports | DentalWin mapping | Notes |
|---|---|---:|---|---|
| `source_system` | text | yes | constant `DentalWin` | Allows future non-DentalWin imports. |
| `source_database_fingerprint` | text/hash | yes | calculated from source database | Avoid relying only on a filename such as `dental.mdb`. |
| `source_table` | text | yes | for example `Customers` | Stored with the original record ID. |
| `source_record_id` | text | yes | `Customers.id` - **Confirmed** | Text storage avoids numeric-format assumptions. |
| `dentalwin_patient_id` | text | yes when present | `Customers.id` - **Confirmed** | Used by `DentalSchoolIstoriko.kodikospelati`. |
| `dentalwin_patient_guid` | text | yes when present | `Customers.EPON` - **Confirmed** | Used as `guidsspelati` by multiple child tables. |
| `legacy_folder_number` | text | no | `Customers.aa_number` / `LST` - **Working/verify** | Preserve both candidates during staging until verified. |
| `migration_batch_id` | relation/text | yes | generated | Connects every result to a dry run and approved import. |
| `imported_at` | timestamp | yes | generated | Not the same as historical patient registration. |
| `raw_source_hash` | text/hash | yes | generated | Supports repeatability and change detection without exposing unnecessary raw data. |

A unique constraint must prevent a duplicate external identifier for the same source database, table, and record ID.

### 5.6 DentalWin screenshot fields awaiting exact database discovery

These visible fields are deliberately recorded without invented source-column names:

- mother's name;
- date of birth;
- sex/gender controls;
- AMKA;
- identity-card number and issue details;
- insurance;
- active status;
- registration date;
- secondary abbreviated occupation field (`Επάγγελμα Μ`);
- family/group value and family-member relationships;
- patient and financial categories;
- place of origin/birth;
- salutations 1 and 2;
- referral source;
- treating/associated doctors;
- contact SMS flags and notes;
- auxiliary fields 1 through 5;
- patient photograph;
- the exact meaning and encoding of `GDPRImage`.

The DentalWin importer must inspect the real schema and representative values before any of these receive a final mapping.

## 6. Current Apexo compatibility mapping

| Current Apexo value | Target handling |
|---|---|
| `id` | Retain as the internal patient ID. |
| `title` | Retain during transition as `legacy_full_name`; use as the display fallback until staff split the name. |
| `birth` integer | Convert to `approximate_birth_year` with precision `year_only`; never invent a day/month. |
| `gender` 0/1 | Preserve as a migrated legacy value and map to the corresponding configured target value; a blank new record uses `unknown`. |
| `phone` combined string/list | Create one contact row per parsed number, label as unspecified unless evidence provides a type, and preserve the original string. |
| `email` | Create an email contact row and preserve the original spelling. |
| `address` | Map to `address_line`. |
| `tags` | Retain unchanged. |
| `notes` | Map to administrative notes, not medical history. |
| `teeth`, `teethExtraNotes` | Remain odontogram migration inputs and are outside this personal-fields blueprint. |
| `link` | Do not treat as personal data. Existing patient-side links require separate security replacement. |
| `archived` | Map to archived status without deleting the patient. |

During transition, the compatibility adapter should read both the old and new shapes. Editing a new field must not erase an old field that is hidden or not present in the current form.

## 7. Display organization

The user interface should expose information progressively.

### 7.1 Everyday summary

- automatic patient registration number;
- surname and first name;
- date of birth or approximate year;
- sex/gender when used;
- primary mobile/phone and email;
- address, city, and postal code;
- profession;
- active/archive state;
- tags and important non-clinical notes.

### 7.2 Additional personal details

- patronymic and mother's name;
- area and country;
- place of origin/birth;
- secondary occupation field after its meaning is confirmed;
- salutations;
- family relationships;
- all additional contacts.

### 7.3 Protected administration

- AMKA, AFM, DOY;
- identity-card and insurance details;
- DentalWin IDs and folder number;
- registration/import dates;
- categories and referral information;
- migration provenance and unresolved legacy values.

Hiding an optional section changes presentation only. It must never delete stored values.

## 8. Search and duplicate behavior

Search indexes should cover authorized fields only and should support:

- Greek case-insensitive and accent-insensitive surname/first-name search;
- exact and normalized phone search;
- case-insensitive email search;
- legacy folder number and external IDs;
- AMKA and AFM for roles authorized to see them.

Duplicate suggestions should consider combinations of name, date/year of birth, phone, email, AMKA, AFM, and external identifiers. The system may suggest matches, but it must not merge patients automatically.

## 9. Security and privacy rules

1. Official identifiers and migration provenance are not public patient-side data.
2. Receptionist and assistant visibility must be decided before server rules are implemented.
3. Access checks must be enforced by PocketBase/server rules, not only by hidden Flutter controls.
4. Audit records should capture creation, edits, archive/restore, merges, and imports, including actor and timestamp.
5. Real DentalWin files and real patient data must never be committed to Git or used in automated test fixtures.
6. Raw source values should be preserved only where needed and protected at least as strongly as the normalized patient record.

## 10. Acceptance criteria for later implementation

The patient foundation is not complete until tests demonstrate that:

1. An old Apexo patient loads without data loss.
2. A staff-created patient can be stored with surname and first name while every other optional field is blank.
3. Every accepted patient receives a unique registration number automatically, including accepted imports and tablet submissions.
4. A tablet submission cannot proceed without surname, first name, and at least one valid mobile, telephone, or email contact.
5. Unknown date of birth and sex/gender remain unknown.
6. A year-only birth value does not become a false exact date.
7. Multiple home, work, mobile, and email contacts round-trip without collapsing into one field.
8. Original contact values survive normalization.
9. Hidden optional values survive unrelated edits.
10. AMKA, AFM, postal codes, and source IDs preserve leading zeroes.
11. Greek search works with and without accents and regardless of letter case.
12. External identifiers prevent the same DentalWin source record from being created twice.
13. Ambiguous imported names and possible duplicates enter a review queue.
14. Archive and restore work without ordinary hard deletion.
15. Unauthorized roles cannot retrieve protected fields directly from PocketBase.
16. No test uses real patient information.

## 11. Decisions still requiring owner confirmation

These decisions should be made before application implementation, but they do not block database discovery:

1. Confirm which fields appear in the everyday patient summary versus the collapsed additional section.
2. Confirm the final labels and allowed values for sex/gender, including `unknown` and any additional value.
3. Clarify the DentalWin label `Επάγγελμα Μ` after reviewing real values.
4. Decide initial receptionist and dental-assistant access to AMKA, AFM, DOY, identity details, address, and administrative notes.
5. Decide whether auxiliary DentalWin fields 1-5 should initially appear in a legacy panel or stay hidden until populated records are reviewed.

## 12. Implementation sequence after blueprint approval

1. Verify unknown DentalWin columns against a schema-only export and representative, privacy-safe values.
2. Finalize the logical and physical PocketBase collections and server authorization rules.
3. Add compatibility tests for the current Apexo patient JSON.
4. Add the new optional patient/contact/external-ID models without changing existing records.
5. Add Greek normalization and duplicate-detection tests.
6. Build the staff patient form in small sections.
7. Build the tablet personal-information form from the same field definitions.
8. Build the DentalWin staging importer and dry-run report.
9. Import real data only after backup, restore, reconciliation, and owner approval are demonstrated with non-production test data.
