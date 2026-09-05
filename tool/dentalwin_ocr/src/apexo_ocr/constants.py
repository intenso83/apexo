from __future__ import annotations

APP_NAME = "Apexo Patient Import Utility"
APP_VERSION = "2.0.0"

SUPPORTED_EXTENSIONS = {
    ".pdf",
    ".jpg",
    ".jpeg",
    ".png",
    ".tif",
    ".tiff",
    ".bmp",
    ".webp",
}

REVIEW_REQUIRED = "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ"
REVIEWED = "ΕΛΕΓΧΘΗΚΕ"
INCLUDE_YES = "YES"
INCLUDE_NO = "NO"

CONTACT_FIELDS = [
    "full_name_raw",
    "last_name",
    "first_name",
    "profession",
    "address",
    "city",
    "area",
    "postal_code",
    "phone",
    "mobile",
    "email",
    "birth_date_raw",
    "birth_date",
    "amka",
    "afm",
    "doy",
    "referrer_raw",
    "referrer",
    "registration_date_raw",
    "registration_date",
]

# This is the exact V6/V7 column order recovered from the approved workflow.
IMPORT_HEADERS = [
    "index",
    "last_name",
    "first_name",
    "profession",
    "address",
    "city",
    "area",
    "postal_code",
    "afm",
    "doy",
    "amka",
    "birth_date",
    "registration_date",
    "mobile",
    "email",
    "referrer",
    "patient_notes",
    "history_reason",
    "history_present_state",
    "history_medicines",
    "history_disease_surgery",
    "history_pregnancy",
    "history_notes",
    "history_allergy_notes",
    "hist_hypertension",
    "hist_cardiovascular",
    "hist_penicillin",
    "hist_latex",
    "hist_asthma",
    "hist_diabetes",
    "hist_endocarditis",
    "hist_epilepsy",
    "hist_pacemaker",
    "hist_antibiotics_before",
    "hist_smoking",
    "hist_alcohol",
    "hist_chemo",
    "hist_neuropathy",
    "hist_coagulation",
]

HISTORY_TEXT_HEADERS = [name for name in IMPORT_HEADERS if name.startswith("history_")]
HISTORY_FLAG_HEADERS = [name for name in IMPORT_HEADERS if name.startswith("hist_")]

OCR_REVIEW_HEADERS = [
    "source_file",
    "source_page",
    "source_sha256",
    "include_in_import",
    "duplicate_of",
    "review_status",
    "engine",
    "model",
    *CONTACT_FIELDS,
    "average_confidence",
    "fields_need_review",
    "extraction_notes",
    "raw_ocr_contact_zones",
]

VALIDATION_HEADERS = [
    "source_file",
    "source_page",
    "severity",
    "field",
    "code",
    "message",
]

REGISTRATION_DATE_HEADERS = [
    "source_file",
    "source_page",
    "registration_date_raw",
    "registration_date",
    "confidence",
    "review_status",
]
