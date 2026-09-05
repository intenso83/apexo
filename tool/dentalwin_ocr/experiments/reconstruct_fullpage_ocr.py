from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any


FIELDS = ("full_name", "address", "mobile", "email", "registration_date")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate and combine full-page dummy OCR results.")
    parser.add_argument("--render-manifest", required=True, type=Path)
    parser.add_argument("--results-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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
        patterns = ("%d/%m/%Y", "%d/%m/%y", "%d-%m-%Y", "%d-%m-%y", "%d.%m.%Y", "%d.%m.%y")
        for pattern in patterns:
            try:
                datetime.strptime(stripped, pattern)
                return []
            except ValueError:
                continue
        return ["invalid_registration_date"]
    return []


def load_page(path: Path, page_number: int) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if set(value) != {"page", "fields"} or value["page"] != page_number:
        raise ValueError(f"Invalid page envelope in {path}")
    if set(value["fields"]) != set(FIELDS):
        raise ValueError(f"Invalid field set in {path}")
    for field_name, field in value["fields"].items():
        if set(field) != {"transcription", "needs_review", "alternatives"}:
            raise ValueError(f"Invalid {field_name} result in {path}")
        if not isinstance(field["transcription"], str) or not isinstance(field["needs_review"], bool):
            raise ValueError(f"Invalid {field_name} value types in {path}")
        if not isinstance(field["alternatives"], list) or not all(isinstance(item, str) for item in field["alternatives"]):
            raise ValueError(f"Invalid {field_name} alternatives in {path}")
    return value


def main() -> int:
    args = parse_args()
    manifest_path = args.render_manifest.resolve(strict=True)
    results_dir = args.results_dir.resolve(strict=True)
    output_path = args.output.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    page_count = int(manifest["rendered_pages"])

    pages: list[dict[str, Any]] = []
    ai_flag_count = 0
    format_issue_count = 0
    result_hashes: list[dict[str, Any]] = []
    for page_number in range(1, page_count + 1):
        result_path = results_dir / f"page-{page_number:02d}.json"
        value = load_page(result_path, page_number)
        fields: dict[str, Any] = {}
        flagged: list[str] = []
        issues: list[str] = []
        for field_name in FIELDS:
            field = value["fields"][field_name]
            field_issues = format_issues(field_name, field["transcription"])
            fields[field_name] = {
                "value": field["transcription"],
                "ai_needs_review": field["needs_review"],
                "alternatives": field["alternatives"],
                "format_issues": field_issues,
            }
            if field["needs_review"]:
                flagged.append(field_name)
            issues.extend(field_issues)
        ai_flag_count += len(flagged)
        format_issue_count += len(issues)
        pages.append({
            "page": page_number,
            "fields": fields,
            "ai_flagged_fields": flagged,
            "format_issues": issues,
            "human_review_status": "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ",
        })
        result_hashes.append({"page": page_number, "result_sha256": sha256(result_path)})

    report = {
        "purpose": "Dummy 17-page whole-page AI OCR comparison test",
        "source_pdf": Path(manifest["source"]).name,
        "source_pdf_sha256": manifest["source_sha256"],
        "recognition": {
            "provider": "OpenAI via Codex ChatGPT sign-in",
            "model": "gpt-5.6-sol",
            "reasoning_effort": "low",
            "one_request_per_full_page": True,
            "block_cropping_used": False,
            "api_key_used": False,
            "ollama_used": False,
        },
        "summary": {
            "page_count": page_count,
            "full_page_request_count": page_count,
            "ai_flag_count": ai_flag_count,
            "format_issue_count": format_issue_count,
            "ready_for_database_import": False,
        },
        "pages": pages,
        "integrity": {
            "render_manifest_sha256": sha256(manifest_path),
            "results": result_hashes,
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(output_path)
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
