from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from threading import Event
from typing import Callable, Sequence

from .constants import INCLUDE_NO
from .documents import contact_zones, discover_inputs, iter_document_pages
from .engines import OcrEngineError, OllamaEngine, TesseractEngine
from .models import OcrRecord
from .validation import duplicate_key, normalize_engine_result
from .workbook import create_review_workbook

ProgressCallback = Callable[[str, int, int], None]


@dataclass(frozen=True)
class PipelineConfig:
    engine: str = "auto"
    endpoint: str = "http://127.0.0.1:11434"
    model: str = "qwen3-vl:4b-instruct-q4_K_M"
    tesseract_path: str | None = None
    dpi: int = 260
    recursive: bool = False
    batch_name: str = ""


@dataclass(frozen=True)
class PipelineResult:
    output_path: Path
    records: tuple[OcrRecord, ...]
    requested_engine: str
    selected_engine: str
    batch_name: str


class PipelineCancelled(RuntimeError):
    pass


def default_batch_name() -> str:
    return f"DW_OCR_{datetime.now():%Y%m%d_%H%M}_CONTACT_V1"


def run_pipeline(
    inputs: Sequence[str | Path],
    output_path: str | Path,
    config: PipelineConfig,
    *,
    progress: ProgressCallback | None = None,
    cancel_event: Event | None = None,
) -> PipelineResult:
    files = discover_inputs(inputs, recursive=config.recursive)
    if not files:
        raise ValueError("Δεν βρέθηκαν υποστηριζόμενα scans.")
    if config.engine not in {"auto", "ollama", "tesseract"}:
        raise ValueError("Άγνωστο OCR engine.")

    ollama = OllamaEngine(config.endpoint, config.model)
    tesseract = TesseractEngine(config.tesseract_path)
    ollama_status = ollama.status() if config.engine in {"auto", "ollama"} else None
    tesseract_status = tesseract.status() if config.engine in {"auto", "tesseract"} else None

    if config.engine == "ollama":
        if ollama_status is None or not ollama_status.available:
            raise OcrEngineError(ollama_status.message if ollama_status else "Το Ollama δεν είναι διαθέσιμο.")
        primary = "ollama"
    elif config.engine == "tesseract":
        if tesseract_status is None or not tesseract_status.available:
            raise OcrEngineError(
                tesseract_status.message if tesseract_status else "Το Tesseract δεν είναι διαθέσιμο."
            )
        primary = "tesseract"
    else:
        if ollama_status is not None and ollama_status.available:
            primary = "ollama"
        elif tesseract_status is not None and tesseract_status.available:
            primary = "tesseract"
        else:
            messages = [status.message for status in (ollama_status, tesseract_status) if status]
            raise OcrEngineError(" / ".join(messages) or "Δεν βρέθηκε local OCR engine.")

    batch = config.batch_name.strip() or default_batch_name()
    records: list[OcrRecord] = []
    used_engines: set[str] = set()
    page_counter = 0
    for file_index, file_path in enumerate(files, start=1):
        _check_cancel(cancel_event)
        if progress:
            progress(f"Άνοιγμα {file_path.name}", file_index - 1, len(files))
        for page in iter_document_pages(file_path, dpi=config.dpi):
            _check_cancel(cancel_event)
            page_counter += 1
            if progress:
                progress(
                    f"OCR {file_path.name}, σελίδα {page.source_page}", file_index - 1, len(files)
                )
            zones = contact_zones(page.image)
            selected = primary
            fallback_note = ""
            try:
                if primary == "ollama":
                    try:
                        payload = ollama.extract(zones)
                    except OcrEngineError:
                        if config.engine != "auto":
                            raise
                        if tesseract_status is None or not tesseract_status.available:
                            raise
                        selected = "tesseract"
                        fallback_note = "Το Ollama απέτυχε για αυτή τη σελίδα· χρησιμοποιήθηκε Tesseract fallback."
                        payload = tesseract.extract(zones)
                else:
                    payload = tesseract.extract(zones)
                record = normalize_engine_result(
                    payload,
                    source_file=file_path.name,
                    source_page=page.source_page,
                    source_sha256=page.source_sha256,
                    engine=selected,
                    model=config.model if selected == "ollama" else "",
                )
                if fallback_note:
                    record.extraction_notes.append(fallback_note)
                records.append(record)
                used_engines.add(selected)
            finally:
                zones.contact.close()
                zones.footer.close()
                page.image.close()

    _mark_duplicates(records)
    selected_label = " + ".join(sorted(used_engines))
    if progress:
        progress("Δημιουργία review workbook", len(files), len(files))
    path = create_review_workbook(
        records,
        output_path,
        batch_name=batch,
        requested_engine=config.engine,
        selected_engine=selected_label,
        model=config.model,
    )
    if progress:
        progress("Ολοκληρώθηκε", len(files), len(files))
    return PipelineResult(
        output_path=path,
        records=tuple(records),
        requested_engine=config.engine,
        selected_engine=selected_label,
        batch_name=batch,
    )


def system_status(config: PipelineConfig) -> dict[str, object]:
    ollama = OllamaEngine(config.endpoint, config.model).status()
    tesseract = TesseractEngine(config.tesseract_path).status()
    return {
        "privacy_boundary": "loopback-only",
        "ollama": {"available": ollama.available, "message": ollama.message, "models": list(ollama.models)},
        "tesseract": {
            "available": tesseract.available,
            "message": tesseract.message,
            "languages": list(tesseract.models),
        },
    }


def _mark_duplicates(records: list[OcrRecord]) -> None:
    seen: dict[tuple[str, str], OcrRecord] = {}
    for record in records:
        key = duplicate_key(record)
        if key is None:
            continue
        first = seen.get(key)
        if first is None:
            seen[key] = record
            continue
        record.include_in_import = INCLUDE_NO
        record.duplicate_of = first.source_label
        record.fields_need_review.append("duplicate")
        record.extraction_notes.append("Πιθανό duplicate: αποκλείστηκε προσωρινά από το Import_Preview.")


def _check_cancel(cancel_event: Event | None) -> None:
    if cancel_event is not None and cancel_event.is_set():
        raise PipelineCancelled("Η επεξεργασία ακυρώθηκε.")
