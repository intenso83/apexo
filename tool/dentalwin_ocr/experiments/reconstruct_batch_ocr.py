from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


FIELDS = ("full_name", "address", "mobile", "email", "registration_date")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Reconstruct a dummy isolated-block OCR batch.")
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--results-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return value


def validate_result(result: dict[str, Any], block_id: str, path: Path) -> None:
    expected = {"block_id", "transcription", "needs_review", "alternatives"}
    if set(result) != expected:
        raise ValueError(f"Unexpected result keys in {path}")
    if result["block_id"] != block_id:
        raise ValueError(f"Block ID mismatch in {path}")
    if not isinstance(result["transcription"], str):
        raise ValueError(f"Invalid transcription in {path}")
    if not isinstance(result["needs_review"], bool):
        raise ValueError(f"Invalid review flag in {path}")
    if not isinstance(result["alternatives"], list) or not all(
        isinstance(item, str) for item in result["alternatives"]
    ):
        raise ValueError(f"Invalid alternatives in {path}")


def format_issues(field: str, value: str) -> list[str]:
    stripped = value.strip()
    if field == "full_name" and not stripped:
        return ["missing_name"]
    if field == "mobile" and stripped:
        digits = "".join(character for character in stripped if character.isdigit())
        return [] if len(digits) == 10 and digits.startswith("69") else ["invalid_mobile"]
    if field == "email" and stripped:
        return [] if re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", stripped) else ["invalid_email"]
    if field == "registration_date" and stripped:
        for pattern in ("%d/%m/%Y", "%d/%m/%y", "%d-%m-%Y", "%d-%m-%y", "%d.%m.%Y", "%d.%m.%y"):
            try:
                datetime.strptime(stripped, pattern)
                return []
            except ValueError:
                continue
        return ["invalid_registration_date"]
    return []


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest.resolve(strict=True)
    results_dir = args.results_dir.resolve(strict=True)
    output_path = args.output.resolve()
    manifest = load_object(manifest_path)

    pages: dict[int, dict[str, Any]] = defaultdict(dict)
    audit: list[dict[str, Any]] = []
    for block in manifest["blocks"]:
        block_id = block["block_id"]
        field = block["field"]
        result_path = results_dir / f"{block_id}.json"
        result = load_object(result_path)
        validate_result(result, block_id, result_path)
        issues = format_issues(field, result["transcription"])
        pages[int(block["page"])][field] = {
            "value": result["transcription"],
            "ai_needs_review": result["needs_review"],
            "alternatives": result["alternatives"],
            "format_issues": issues,
            "block_id": block_id,
        }
        audit.append(
            {
                "page": block["page"],
                "field": field,
                "block_id": block_id,
                "result_sha256": sha256(result_path),
            }
        )

    page_rows: list[dict[str, Any]] = []
    ai_flag_count = 0
    format_issue_count = 0
    for page in sorted(pages):
        missing = [field for field in FIELDS if field not in pages[page]]
        if missing:
            raise ValueError(f"Page {page} is missing fields: {missing}")
        flagged_fields = [field for field in FIELDS if pages[page][field]["ai_needs_review"]]
        page_format_issues = [
            issue
            for field in FIELDS
            for issue in pages[page][field]["format_issues"]
        ]
        ai_flag_count += len(flagged_fields)
        format_issue_count += len(page_format_issues)
        page_rows.append(
            {
                "page": page,
                "fields": pages[page],
                "ai_flagged_fields": flagged_fields,
                "format_issues": page_format_issues,
                "human_review_status": "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ",
            }
        )

    report = {
        "purpose": "Dummy 17-page isolated-block OCR batch test",
        "source_pdf": Path(manifest["source_pdf"]).name,
        "source_pdf_sha256": manifest["source_pdf_sha256"],
        "recognition": {
            "provider": "OpenAI via Codex ChatGPT sign-in",
            "model": "gpt-5.6-sol",
            "reasoning_effort": "low",
            "one_request_per_block": True,
            "api_key_used": False,
            "ollama_used": False,
        },
        "summary": {
            "page_count": len(page_rows),
            "block_count": len(audit),
            "ai_flag_count": ai_flag_count,
            "format_issue_count": format_issue_count,
            "ready_for_database_import": False,
        },
        "pages": page_rows,
        "integrity": {
            "manifest_sha256": sha256(manifest_path),
            "results": audit,
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(output_path)
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
