import json
import sqlite3
import sys
from pathlib import Path


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    database = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None

    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    try:
        counts = connection.execute(
            "SELECT store, COUNT(*) FROM data GROUP BY store ORDER BY store"
        ).fetchall()
        print(json.dumps({"stores": counts}, ensure_ascii=False, indent=2))

        payload = {}
        for store in ("therapy_groups", "procedure_catalog"):
            rows = connection.execute(
                "SELECT id, data FROM data WHERE store = ? ORDER BY id", (store,)
            ).fetchall()
            payload[store] = [
                {"record_id": record_id, **json.loads(raw_data)}
                for record_id, raw_data in rows
            ]
            sample = payload[store][0] if payload[store] else None
            print(
                json.dumps(
                    {"store": store, "count": len(rows), "sample": sample},
                    ensure_ascii=False,
                    indent=2,
                )
            )

        if output is not None:
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            print(f"Wrote catalogue-only extract to {output}")
    finally:
        connection.close()


if __name__ == "__main__":
    main()
