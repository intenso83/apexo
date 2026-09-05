from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reconstruct independently recognized OCR blocks using a local map."
    )
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--results-dir", required=True, type=Path)
    parser.add_argument("--retry-results-dir", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--model", required=True)
    return parser.parse_args()


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return value


def validate_result(result: dict[str, Any], expected_id: str, path: Path) -> None:
    expected_keys = {"block_id", "transcription", "needs_review", "alternatives"}
    if set(result) != expected_keys:
        raise ValueError(f"Unexpected keys in {path}: {sorted(result)}")
    if result["block_id"] != expected_id:
        raise ValueError(f"Block ID mismatch in {path}")
    if not isinstance(result["transcription"], str):
        raise ValueError(f"Invalid transcription in {path}")
    if not isinstance(result["needs_review"], bool):
        raise ValueError(f"Invalid needs_review flag in {path}")
    if not isinstance(result["alternatives"], list) or not all(
        isinstance(item, str) for item in result["alternatives"]
    ):
        raise ValueError(f"Invalid alternatives in {path}")


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest.resolve(strict=True)
    results_dir = args.results_dir.resolve(strict=True)
    retry_results_dir = (
        args.retry_results_dir.resolve(strict=True) if args.retry_results_dir else None
    )
    output_path = args.output.resolve()
    manifest = load_json(manifest_path)

    reconstructed: dict[str, Any] = {}
    result_audit: list[dict[str, Any]] = []
    for block in manifest.get("blocks", []):
        block_id = block["block_id"]
        result_path = results_dir / f"{block_id}.json"
        result = load_json(result_path)
        validate_result(result, block_id, result_path)
        selected = result
        retry_result: dict[str, Any] | None = None
        retry_path = retry_results_dir / f"{block_id}.json" if retry_results_dir else None
        if retry_path and retry_path.exists():
            retry_result = load_json(retry_path)
            validate_result(retry_result, block_id, retry_path)
            selected = retry_result

        passes_disagree = bool(
            retry_result
            and retry_result["transcription"].strip() != result["transcription"].strip()
        )
        review_reasons: list[str] = []
        if selected["needs_review"]:
            review_reasons.append("model_marked_uncertain")
        if passes_disagree:
            review_reasons.append("passes_disagree")
        reconstructed[block["field"]] = {
            "value": selected["transcription"],
            "needs_review": bool(review_reasons),
            "review_reasons": review_reasons,
            "alternatives": selected["alternatives"],
            "passes": [
                {
                    "kind": "generic",
                    "transcription": result["transcription"],
                    "needs_review": result["needs_review"],
                },
                *(
                    [
                        {
                            "kind": "field_aware_retry",
                            "transcription": retry_result["transcription"],
                            "needs_review": retry_result["needs_review"],
                        }
                    ]
                    if retry_result
                    else []
                ),
            ],
        }
        result_audit.append(
            {
                "block_id": block_id,
                "generic_result_sha256": file_sha256(result_path),
                **(
                    {"retry_result_sha256": file_sha256(retry_path)}
                    if retry_result and retry_path
                    else {}
                ),
            }
        )

    review_fields = [
        field for field, value in reconstructed.items() if value["needs_review"]
    ]
    report = {
        "purpose": "Dummy-data isolated block OCR proof of concept",
        "source_sha256": manifest["source_sha256"],
        "recognition": {
            "provider": "OpenAI via Codex ChatGPT sign-in",
            "model": args.model,
            "one_request_per_block": True,
            "field_aware_retry_used": retry_results_dir is not None,
            "api_key_used": False,
            "ollama_used": False,
        },
        "reconstructed_locally": True,
        "fields": reconstructed,
        "summary": {
            "field_count": len(reconstructed),
            "accepted_without_disagreement": len(reconstructed) - len(review_fields),
            "needs_human_review": len(review_fields),
            "review_fields": review_fields,
            "ready_for_database_import": False,
        },
        "integrity": {
            "manifest_sha256": file_sha256(manifest_path),
            "results": result_audit,
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
