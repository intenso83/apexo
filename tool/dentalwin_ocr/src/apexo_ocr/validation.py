from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime
from typing import Any

from .constants import CONTACT_FIELDS, REVIEW_REQUIRED
from .models import OcrRecord, ValidationIssue


def text(value: Any) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip()


def digits(value: Any) -> str:
    return re.sub(r"\D", "", text(value))


def fold(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", text(value).upper())
    return "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn")


def normalize_email(value: Any) -> str:
    return text(value).replace(" ", "").lower()


def normalize_identifier(value: Any) -> str:
    raw = text(value)
    normalized = digits(raw)
    return normalized if normalized else raw


def normalize_phone(value: Any) -> str:
    raw = text(value)
    if not raw:
        return ""
    prefix = "+" if raw.lstrip().startswith("+") else ""
    return prefix + digits(raw)


def normalize_date(value: Any) -> str:
    raw = text(value)
    if not raw:
        return ""
    if isinstance(value, (datetime, date)):
        return value.strftime("%Y-%m-%d")
    cleaned = raw.replace(".", "/").replace("-", "/")
    formats = ["%Y/%m/%d", "%d/%m/%Y", "%d/%m/%y"]
    for pattern in formats:
        try:
            parsed = datetime.strptime(cleaned, pattern).date()
        except ValueError:
            continue
        if parsed.year < 1900 or parsed.year > date.today().year + 1:
            return ""
        return parsed.isoformat()
    return ""


def valid_email(value: str) -> bool:
    if not value:
        return True
    return bool(re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value))


def valid_afm(value: str) -> bool:
    value = digits(value)
    if len(value) != 9:
        return False
    checksum = sum(int(value[i]) * (2 ** (8 - i)) for i in range(8))
    return (checksum % 11) % 10 == int(value[8])


def plausible_amka(value: str) -> bool:
    value = digits(value)
    if len(value) != 11:
        return False
    try:
        day, month, year = int(value[:2]), int(value[2:4]), int(value[4:6])
        current_two = date.today().year % 100
        century = 2000 if year <= current_two else 1900
        datetime(century + year, month, day)
        return True
    except ValueError:
        return False


def normalize_engine_result(
    payload: dict[str, Any],
    *,
    source_file: str,
    source_page: int,
    source_sha256: str,
    engine: str,
    model: str = "",
) -> OcrRecord:
    raw_values = payload.get("values") if isinstance(payload.get("values"), dict) else payload
    confidence_raw = payload.get("confidence", {})
    confidence: dict[str, float] = {}
    if isinstance(confidence_raw, dict):
        for key, value in confidence_raw.items():
            try:
                confidence[key] = max(0.0, min(1.0, float(value)))
            except (TypeError, ValueError):
                continue

    values = {name: text(raw_values.get(name, "")) for name in CONTACT_FIELDS}
    values["email"] = normalize_email(values["email"])
    for name in ("amka", "afm", "postal_code"):
        values[name] = normalize_identifier(values[name])
    for name in ("phone", "mobile"):
        values[name] = normalize_phone(values[name])

    for normalized, raw_name in (
        ("birth_date", "birth_date_raw"),
        ("registration_date", "registration_date_raw"),
    ):
        raw = values.get(raw_name) or values.get(normalized)
        parsed = normalize_date(raw)
        values[raw_name] = raw
        values[normalized] = parsed

    flags = payload.get("fields_need_review", [])
    if not isinstance(flags, list):
        flags = [text(flags)] if flags else []
    notes_value = payload.get("notes", [])
    if isinstance(notes_value, str):
        notes = [text(notes_value)] if text(notes_value) else []
    elif isinstance(notes_value, list):
        notes = [text(item) for item in notes_value if text(item)]
    else:
        notes = []

    record = OcrRecord(
        source_file=source_file,
        source_page=source_page,
        source_sha256=source_sha256,
        engine=engine,
        model=model,
        values=values,
        confidence=confidence,
        fields_need_review=[text(item) for item in flags if text(item)],
        extraction_notes=notes,
        raw_ocr_contact_zones=text(payload.get("raw_ocr_contact_zones", "")),
        review_status=REVIEW_REQUIRED,
    )
    validate_record(record)
    return record


def validate_record(record: OcrRecord) -> None:
    values = record.values
    issues: list[ValidationIssue] = []

    if not values["last_name"]:
        issues.append(ValidationIssue("last_name", "required", "Το επώνυμο είναι κενό."))
    if not values["first_name"]:
        issues.append(ValidationIssue("first_name", "required", "Το όνομα είναι κενό."))
    if values["email"] and not valid_email(values["email"]):
        issues.append(ValidationIssue("email", "invalid_format", "Το email χρειάζεται έλεγχο."))
    if values["amka"] and not plausible_amka(values["amka"]):
        issues.append(ValidationIssue("amka", "invalid_or_implausible", "Το ΑΜΚΑ χρειάζεται έλεγχο."))
    if values["afm"] and not valid_afm(values["afm"]):
        issues.append(ValidationIssue("afm", "checksum_failed", "Ο έλεγχος ψηφίου ΑΦΜ απέτυχε."))
    if values["postal_code"] and len(digits(values["postal_code"])) != 5:
        issues.append(ValidationIssue("postal_code", "invalid_length", "Ο ΤΚ δεν έχει 5 ψηφία."))
    for name in ("mobile", "phone"):
        number = digits(values[name])
        if number and not (len(number) == 10 or values[name].startswith("+")):
            issues.append(ValidationIssue(name, "invalid_length", "Ο αριθμός τηλεφώνου χρειάζεται έλεγχο."))
    for normalized, raw_name in (
        ("birth_date", "birth_date_raw"),
        ("registration_date", "registration_date_raw"),
    ):
        if values[raw_name] and not values[normalized]:
            issues.append(ValidationIssue(normalized, "invalid_date", "Η ημερομηνία χρειάζεται έλεγχο."))
    if not values["registration_date"]:
        issues.append(
            ValidationIssue(
                "registration_date",
                "missing",
                "Δεν βρέθηκε ασφαλής ημερομηνία φόρμας/εγγραφής.",
            )
        )

    for name, confidence in record.confidence.items():
        if name in CONTACT_FIELDS and record.values.get(name) and confidence < 0.72:
            issues.append(ValidationIssue(name, "low_confidence", "Χαμηλή βεβαιότητα OCR."))

    for issue in issues:
        if issue.field not in record.fields_need_review:
            record.fields_need_review.append(issue.field)
    record.validation_issues = issues


def duplicate_key(record: OcrRecord) -> tuple[str, str] | None:
    values = record.values
    if plausible_amka(values["amka"]):
        return ("amka", values["amka"])
    if valid_afm(values["afm"]):
        return ("afm", values["afm"])
    normalized_name = fold(f"{values['last_name']} {values['first_name']}")
    if normalized_name and values["birth_date"]:
        return ("name_birth", f"{normalized_name}|{values['birth_date']}")
    if normalized_name and values["mobile"]:
        return ("name_mobile", f"{normalized_name}|{values['mobile']}")
    return None
