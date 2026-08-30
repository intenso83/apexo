"""Export approved catalogue language snapshots from the audit workbook."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from openpyxl import load_workbook


def main() -> None:
    workbook_path = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2]).resolve()
    workbook = load_workbook(workbook_path, read_only=True, data_only=True)
    sheet = workbook["Catalogue Audit"]

    headers = {
        str(cell.value): index
        for index, cell in enumerate(sheet[5], start=1)
        if cell.value is not None
    }
    required = {
        "Source code",
        "Group — Greek",
        "Procedure — Greek (source)",
        "English draft",
        "German draft",
        "Source record ID",
    }
    missing = required - headers.keys()
    if missing:
        raise RuntimeError(f"Missing workbook columns: {sorted(missing)}")

    records: list[dict[str, str]] = []
    for row in sheet.iter_rows(min_row=6, values_only=True):
        record_id = row[headers["Source record ID"] - 1]
        if not record_id:
            continue
        records.append(
            {
                "recordID": str(record_id),
                "sourceCode": str(row[headers["Source code"] - 1] or ""),
                "groupGreek": str(row[headers["Group — Greek"] - 1] or ""),
                "greek": str(row[headers["Procedure — Greek (source)"] - 1] or ""),
                "english": str(row[headers["English draft"] - 1] or ""),
                "german": str(row[headers["German draft"] - 1] or ""),
            }
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(records)} catalogue translations to {output_path}")


if __name__ == "__main__":
    main()
