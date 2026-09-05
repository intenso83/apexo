from __future__ import annotations

import csv
import hashlib
import io
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from .constants import HISTORY_FLAG_HEADERS, HISTORY_TEXT_HEADERS, IMPORT_HEADERS
from .validation import (
    digits,
    fold,
    normalize_date,
    normalize_email,
    normalize_identifier,
    normalize_phone,
    plausible_amka,
    valid_afm,
    valid_email,
)


MAX_CSV_BYTES = 10 * 1024 * 1024
MAX_PATIENT_ROWS = 500

# Limits are the narrowest confirmed values in the DentalWin V6/V7 target.
FIELD_LIMITS = {
    "last_name": 50,
    "first_name": 50,
    "profession": 100,
    "address": 255,
    "city": 255,
    "area": 255,
    "postal_code": 255,
    "afm": 50,
    "doy": 50,
    "amka": 255,
    "mobile": 255,
    "email": 255,
    "referrer": 255,
}


class CsvContractError(ValueError):
    pass


@dataclass(frozen=True)
class CsvIssue:
    row_number: int
    field: str
    code: str
    message: str
    severity: str = "error"

    def safe_dict(self) -> dict[str, object]:
        return {
            "row_number": self.row_number,
            "field": self.field,
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
        }


@dataclass(frozen=True)
class CsvPatient:
    row_number: int
    values: dict[str, str]
    row_sha256: str

    @property
    def source_index(self) -> str:
        return self.values["index"]


@dataclass
class CsvValidationReport:
    source_path: Path
    source_sha256: str
    source_size_bytes: int
    rows: list[CsvPatient] = field(default_factory=list)
    issues: list[CsvIssue] = field(default_factory=list)

    @property
    def errors(self) -> list[CsvIssue]:
        return [issue for issue in self.issues if issue.severity == "error"]

    @property
    def warnings(self) -> list[CsvIssue]:
        return [issue for issue in self.issues if issue.severity != "error"]

    @property
    def valid(self) -> bool:
        return bool(self.rows) and not self.errors

    def safe_summary(self) -> dict[str, object]:
        return {
            "format": "apexo-reviewed-patient-csv-v1",
            "source_file": self.source_path.name,
            "source_sha256": self.source_sha256,
            "source_size_bytes": self.source_size_bytes,
            "row_count": len(self.rows),
            "error_count": len(self.errors),
            "warning_count": len(self.warnings),
            "valid": self.valid,
            "issues": [issue.safe_dict() for issue in self.issues],
            "contains_patient_values": False,
        }


def load_reviewed_csv(path: str | Path) -> CsvValidationReport:
    source = Path(path).expanduser().resolve()
    if not source.is_file():
        raise CsvContractError("Το reviewed CSV δεν βρέθηκε.")
    if source.suffix.lower() != ".csv":
        raise CsvContractError("Το input πρέπει να είναι αρχείο .csv.")
    size = source.stat().st_size
    if size <= 0:
        raise CsvContractError("Το CSV είναι κενό.")
    if size > MAX_CSV_BYTES:
        raise CsvContractError("Το CSV υπερβαίνει το ασφαλές όριο των 10 MB.")
    source_hash = _sha256_file(source)
    try:
        content = source.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError as exc:
        raise CsvContractError("Το CSV πρέπει να είναι UTF-8 ή UTF-8 with BOM.") from exc
    if "\x00" in content:
        raise CsvContractError("Το CSV περιέχει μη έγκυρους NUL χαρακτήρες.")

    report = CsvValidationReport(
        source_path=source,
        source_sha256=source_hash,
        source_size_bytes=size,
    )
    try:
        reader = csv.reader(io.StringIO(content, newline=""), strict=True)
        header = next(reader, None)
        if header is None:
            raise CsvContractError("Το CSV δεν έχει header row.")
        if header != IMPORT_HEADERS:
            raise CsvContractError(
                "Τα CSV headers ή η σειρά τους δεν ταιριάζουν με το εγκεκριμένο V6/V7 schema."
            )
        for row_number, cells in enumerate(reader, start=2):
            if not any(cell.strip() for cell in cells):
                continue
            if len(cells) != len(IMPORT_HEADERS):
                report.issues.append(
                    CsvIssue(
                        row_number,
                        "row",
                        "wrong_column_count",
                        f"Η γραμμή έχει {len(cells)} αντί για {len(IMPORT_HEADERS)} στήλες.",
                    )
                )
                continue
            values = {name: _clean_cell(value) for name, value in zip(IMPORT_HEADERS, cells)}
            _normalize_patient_values(values)
            _validate_patient_row(row_number, values, report.issues)
            row_hash = hashlib.sha256(
                json.dumps(values, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode(
                    "utf-8"
                )
            ).hexdigest()
            report.rows.append(CsvPatient(row_number, values, row_hash))
    except csv.Error as exc:
        raise CsvContractError(f"Το CSV δεν είναι έγκυρο: {exc}.") from exc

    if len(report.rows) > MAX_PATIENT_ROWS:
        report.issues.append(
            CsvIssue(
                1,
                "row",
                "too_many_rows",
                f"Το αρχείο έχει πάνω από {MAX_PATIENT_ROWS} γραμμές και μπλοκαρίστηκε.",
            )
        )
    if not report.rows:
        report.issues.append(CsvIssue(1, "row", "no_rows", "Το CSV δεν περιέχει ασθενείς."))
    _validate_unique_indices(report)
    _validate_internal_duplicates(report)
    return report


def write_safe_report(report: CsvValidationReport, path: str | Path) -> Path:
    target = Path(path).expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(report.safe_summary(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return target


def _clean_cell(value: str) -> str:
    return re.sub(r"[\t\r\n]+", " ", value).strip()


def _normalize_patient_values(values: dict[str, str]) -> None:
    values["email"] = normalize_email(values["email"])
    values["mobile"] = normalize_phone(values["mobile"])
    for name in ("amka", "afm", "postal_code"):
        values[name] = normalize_identifier(values[name])
    for name in ("birth_date", "registration_date"):
        if values[name]:
            normalized = normalize_date(values[name])
            if normalized:
                values[name] = normalized
    for name in HISTORY_FLAG_HEADERS:
        if values[name].lower() in {"", "0", "0.0", "false"}:
            values[name] = "0"


def _validate_patient_row(
    row_number: int, values: dict[str, str], issues: list[CsvIssue]
) -> None:
    if not values["last_name"]:
        issues.append(CsvIssue(row_number, "last_name", "required", "Το επώνυμο είναι κενό."))
    if not values["first_name"]:
        issues.append(CsvIssue(row_number, "first_name", "required", "Το όνομα είναι κενό."))

    try:
        int(values["index"])
    except ValueError:
        issues.append(CsvIssue(row_number, "index", "invalid_integer", "Το index δεν είναι ακέραιος."))

    for name in ("birth_date", "registration_date"):
        if values[name] and not normalize_date(values[name]):
            issues.append(
                CsvIssue(row_number, name, "invalid_date", "Η ημερομηνία δεν είναι έγκυρη.")
            )
    if values["email"] and not valid_email(values["email"]):
        issues.append(CsvIssue(row_number, "email", "invalid_email", "Το email δεν είναι έγκυρο."))
    if values["afm"] and not valid_afm(values["afm"]):
        issues.append(
            CsvIssue(row_number, "afm", "invalid_afm_checksum", "Ο έλεγχος ψηφίου ΑΦΜ απέτυχε.")
        )
    if values["amka"] and not plausible_amka(values["amka"]):
        issues.append(CsvIssue(row_number, "amka", "invalid_amka", "Το ΑΜΚΑ δεν είναι έγκυρο."))
    if values["postal_code"] and (
        not values["postal_code"].isdigit() or len(values["postal_code"]) != 5
    ):
        issues.append(
            CsvIssue(row_number, "postal_code", "invalid_postal_code", "Ο ΤΚ πρέπει να έχει 5 ψηφία.")
        )
    mobile_digits = digits(values["mobile"])
    if values["mobile"] and not (10 <= len(mobile_digits) <= 15):
        issues.append(
            CsvIssue(row_number, "mobile", "invalid_mobile", "Το κινητό πρέπει να έχει 10–15 ψηφία.")
        )

    for name, limit in FIELD_LIMITS.items():
        if len(values[name]) > limit:
            issues.append(
                CsvIssue(
                    row_number,
                    name,
                    "target_length_exceeded",
                    f"Η τιμή υπερβαίνει το DentalWin όριο των {limit} χαρακτήρων.",
                )
            )
    for name, value in values.items():
        if any(ord(character) < 32 for character in value):
            issues.append(
                CsvIssue(row_number, name, "control_character", "Η τιμή περιέχει control χαρακτήρα.")
            )

    if values["patient_notes"]:
        issues.append(
            CsvIssue(
                row_number,
                "patient_notes",
                "contact_only_scope",
                "Το contact-only import δεν επιτρέπει patient_notes.",
            )
        )
    for name in HISTORY_TEXT_HEADERS:
        if values[name]:
            issues.append(
                CsvIssue(
                    row_number,
                    name,
                    "contact_only_scope",
                    "Το contact-only import δεν επιτρέπει medical-history text.",
                )
            )
    for name in HISTORY_FLAG_HEADERS:
        if values[name] != "0":
            issues.append(
                CsvIssue(
                    row_number,
                    name,
                    "contact_only_scope",
                    "Το contact-only import δεν επιτρέπει medical-history flags.",
                )
            )


def _validate_unique_indices(report: CsvValidationReport) -> None:
    by_index: dict[str, list[int]] = {}
    for patient in report.rows:
        by_index.setdefault(patient.source_index, []).append(patient.row_number)
    for index, row_numbers in by_index.items():
        if index and len(row_numbers) > 1:
            for row_number in row_numbers:
                report.issues.append(
                    CsvIssue(
                        row_number,
                        "index",
                        "duplicate_index",
                        "Το index εμφανίζεται περισσότερες από μία φορές.",
                    )
                )


def _validate_internal_duplicates(report: CsvValidationReport) -> None:
    keys: dict[tuple[str, str], list[int]] = {}
    for patient in report.rows:
        for key in _patient_duplicate_keys(patient.values):
            keys.setdefault(key, []).append(patient.row_number)
    duplicate_rows: dict[int, set[str]] = {}
    for (kind, _), row_numbers in keys.items():
        unique_rows = sorted(set(row_numbers))
        if len(unique_rows) <= 1:
            continue
        for row_number in unique_rows:
            duplicate_rows.setdefault(row_number, set()).add(kind)
    for row_number, kinds in sorted(duplicate_rows.items()):
        report.issues.append(
            CsvIssue(
                row_number,
                "duplicate",
                "duplicate_inside_csv",
                "Πιθανό duplicate μέσα στο CSV (" + ", ".join(sorted(kinds)) + ").",
            )
        )


def patient_duplicate_keys(values: dict[str, str]) -> set[tuple[str, str]]:
    return _patient_duplicate_keys(values)


def _patient_duplicate_keys(values: dict[str, str]) -> set[tuple[str, str]]:
    keys: set[tuple[str, str]] = set()
    if values["amka"]:
        keys.add(("amka", values["amka"]))
    if values["afm"]:
        keys.add(("afm", values["afm"]))
    if values["email"]:
        keys.add(("email", values["email"].lower()))
    if values["mobile"]:
        keys.add(("mobile", digits(values["mobile"])))
    name = fold(f"{values['last_name']} {values['first_name']}")
    if name and values["birth_date"]:
        keys.add(("name_birth", f"{name}|{values['birth_date']}"))
    return keys


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rows_fingerprint(rows: Iterable[CsvPatient]) -> str:
    digest = hashlib.sha256()
    for row_hash in sorted(patient.row_sha256 for patient in rows):
        digest.update(row_hash.encode("ascii"))
    return digest.hexdigest()
