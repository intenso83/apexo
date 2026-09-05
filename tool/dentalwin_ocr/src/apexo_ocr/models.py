from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .constants import (
    CONTACT_FIELDS,
    HISTORY_FLAG_HEADERS,
    HISTORY_TEXT_HEADERS,
    IMPORT_HEADERS,
    INCLUDE_YES,
    REVIEW_REQUIRED,
)


@dataclass(frozen=True)
class ValidationIssue:
    field: str
    code: str
    message: str
    severity: str = "warning"


@dataclass
class OcrRecord:
    source_file: str
    source_page: int
    source_sha256: str
    engine: str
    model: str = ""
    values: dict[str, str] = field(default_factory=dict)
    confidence: dict[str, float] = field(default_factory=dict)
    fields_need_review: list[str] = field(default_factory=list)
    extraction_notes: list[str] = field(default_factory=list)
    raw_ocr_contact_zones: str = ""
    validation_issues: list[ValidationIssue] = field(default_factory=list)
    include_in_import: str = INCLUDE_YES
    duplicate_of: str = ""
    review_status: str = REVIEW_REQUIRED

    def __post_init__(self) -> None:
        for name in CONTACT_FIELDS:
            self.values.setdefault(name, "")

    @property
    def average_confidence(self) -> float:
        present = [
            float(self.confidence.get(name, 0.0))
            for name in CONTACT_FIELDS
            if self.values.get(name, "").strip()
        ]
        return sum(present) / len(present) if present else 0.0

    @property
    def source_label(self) -> str:
        return f"{self.source_file}#page={self.source_page}"

    def review_row(self) -> dict[str, Any]:
        row: dict[str, Any] = {
            "source_file": self.source_file,
            "source_page": str(self.source_page),
            "source_sha256": self.source_sha256,
            "include_in_import": self.include_in_import,
            "duplicate_of": self.duplicate_of,
            "review_status": self.review_status,
            "engine": self.engine,
            "model": self.model,
        }
        row.update({name: self.values.get(name, "") for name in CONTACT_FIELDS})
        row.update(
            {
                "average_confidence": f"{self.average_confidence:.2f}",
                "fields_need_review": "; ".join(sorted(set(self.fields_need_review))),
                "extraction_notes": "; ".join(self.extraction_notes),
                "raw_ocr_contact_zones": self.raw_ocr_contact_zones,
            }
        )
        return row

    def import_row(self, index: int) -> dict[str, str]:
        row = {name: "" for name in IMPORT_HEADERS}
        row["index"] = str(index)
        for name in (
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
        ):
            row[name] = self.values.get(name, "")

        # This utility is deliberately contact-only. Medical history is never
        # copied from OCR output into the DentalWin import surface.
        row["patient_notes"] = ""
        for name in HISTORY_TEXT_HEADERS:
            row[name] = ""
        for name in HISTORY_FLAG_HEADERS:
            row[name] = "0"
        return row


@dataclass(frozen=True)
class RenderedPage:
    source_path: Path
    source_page: int
    source_sha256: str
    image: Any


@dataclass(frozen=True)
class PageZones:
    contact: Any
    footer: Any
