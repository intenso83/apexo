# Practice medical-history questionnaire blueprint

Status: implementation baseline, 2026-09-02

Canonical questionnaire version: `practice-medical-history-2026-09-02-v1`

## Purpose

The Android/manual-entry form, future tablet intake, paper/OCR workflow, and
DentalWin migration must use the same stable field IDs. Display text may be
translated or improved, but stored answers are keyed by the IDs defined in
`lib/features/medical_history/medical_history_questionnaire.dart`.

Every saved questionnaire is a new `medical_history_revisions` record. A
previous signed, submitted, reviewed, or imported record is never overwritten.

## Paper-form reconciliation

The Greek, English, and German practice forms have the same medical-history
core. Their union is the canonical baseline:

- The Greek personal section includes AMKA and AFM/DOY. The English form adds
  place/country of origin. The German form adds insurance. The patient model
  retains all of these fields so no language-specific value is lost.
- The Greek form includes the unpleasant-reaction question that is absent from
  the supplied English and German forms. It is retained as
  `adverse_dental_reaction` in all languages.
- The old bisphosphonate wording is broadened to `antiresorptive_therapy`, while
  still mentioning bisphosphonates on the displayed form.
- The cardiovascular parent answer and its individual subquestions have
  separate stable IDs.
- Manual/tablet responses support `yes`, `no`, `unknown`, and
  `not_applicable`. Paper/OCR ambiguity remains `unknown` and requires review.

Referral source remains part of the patient record. Form date, confirmation,
signature metadata, source, language, status, and reviewer data belong to each
medical-history revision.

## Confirmed DentalWin mapping

Each `DentalSchoolIstoriko` row is staged as one immutable revision. The
migration preserves raw values and does not infer a diagnosis from free text.

| DentalWin column | Revision destination |
|---|---|
| `aitiaproelesi` | `reason_for_visit` |
| `parousakatastai` | `present_condition` |
| `MEMOS36` | `legacy_medicines_text` |
| `MEMOS28` | `diseases_surgeries` |
| `MEMOS29` | pregnancy response notes, `unknown` pending review |
| `MEMOS220` | `general_notes` |
| `penikilinh` | `answers.penicillin_allergy`, imported/pending review |
| `latex` | `answers.latex_allergy`, imported/pending review |
| `ypertasi` | `answers.blood_pressure_disorder`, imported/pending review |
| `kardiaggiaki` | `answers.cardiovascular_disease`, imported/pending review |

The staging record retains the full staged payload in
`legacy_raw_payload` and provenance in `provenance`.

## Deliberately unverified DentalWin mappings

Asthma, diabetes, endocarditis, epilepsy, pacemaker, antibiotic prophylaxis,
smoking, alcohol use, chemotherapy, neurological history, and coagulation
disorder are valid target questions. Their exact DentalWin source columns must
be verified against a source-column/value audit before direct mapping. Until
then, the migration must preserve candidate raw fields for review and must not
turn them into definite answers or clinical alerts.

## Current implementation boundary

- Staff can create a responsive manual revision from a saved patient.
- Revisions synchronize through the generic Apexo data collection under the
  `medical_history_revisions` store name.
- Imported flags and OCR-style uncertainty are visibly marked for review.
- The model carries patient confirmation and signature metadata; handwritten
  scans or tablet signature files remain separate document attachments.
- The full restricted kiosk/intake-session workflow and clinical-alert review
  UI are later layers; the canonical model is ready for both.
