from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

from openpyxl import load_workbook
from PIL import Image, ImageDraw, ImageFont

from .apexo_import import dry_run_apexo, import_apexo
from .constants import APP_NAME, APP_VERSION, REVIEWED
from .csv_contract import load_reviewed_csv
from .dentalwin_import import dry_run_dentalwin, import_dentalwin
from .documents import iter_document_pages
from .models import OcrRecord
from .pipeline import PipelineConfig, run_pipeline, system_status
from .workbook import create_review_workbook, export_reviewed_csv


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate and import an approved patient CSV into DentalWin or Apexo"
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {APP_VERSION}")
    parser.add_argument("--input", nargs="+", help="Scan file(s) or folder(s)")
    parser.add_argument("--output", help="Review .xlsx output")
    parser.add_argument("--batch", default="", help="Batch name")
    parser.add_argument("--engine", choices=("auto", "ollama", "tesseract"), default="auto")
    parser.add_argument("--endpoint", default="http://127.0.0.1:11434")
    parser.add_argument("--model", default="qwen3-vl:4b-instruct-q4_K_M")
    parser.add_argument("--tesseract", default=None)
    parser.add_argument("--dpi", type=int, default=260)
    parser.add_argument("--recursive", action="store_true")
    parser.add_argument("--check", action="store_true", help="Check local OCR engines")
    parser.add_argument("--export-reviewed", help="Reviewed .xlsx to export")
    parser.add_argument("--csv-output", help="CSV path (default: patients_import.csv beside workbook)")
    parser.add_argument("--allow-unreviewed", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--gui-smoke-test", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--reviewed-csv", help="Validate/import the approved structured CSV")
    parser.add_argument("--target", choices=("dentalwin", "apexo"))
    parser.add_argument("--database", help="DentalWin .mdb/.accdb target")
    parser.add_argument("--apexo-url", help="Apexo/PocketBase root URL")
    parser.add_argument("--apexo-email", help="Apexo account email")
    parser.add_argument("--password-file", help="File containing the Apexo password")
    parser.add_argument("--commit", action="store_true", help="Commit after a successful dry run")
    parser.add_argument("--confirm", help="First 12 characters of the validated CSV SHA-256")
    return parser


def main(argv: list[str] | None = None) -> int:
    _configure_console_encoding()
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments:
        _hide_console()
        from .gui import launch_gui

        launch_gui()
        return 0
    parser = build_parser()
    args = parser.parse_args(arguments)
    config = PipelineConfig(
        engine=args.engine,
        endpoint=args.endpoint,
        model=args.model,
        tesseract_path=args.tesseract,
        dpi=max(150, min(600, args.dpi)),
        recursive=args.recursive,
        batch_name=args.batch,
    )
    try:
        if args.self_test:
            print(json.dumps(run_self_test(), ensure_ascii=False, indent=2))
            return 0
        if args.gui_smoke_test:
            run_gui_smoke_test()
            print("GUI runtime OK")
            return 0
        if args.reviewed_csv:
            return _run_csv_command(args)
        if args.check:
            print(json.dumps(system_status(config), ensure_ascii=False, indent=2))
            return 0
        if args.export_reviewed:
            target = args.csv_output or str(Path(args.export_reviewed).resolve().parent / "patients_import.csv")
            output = export_reviewed_csv(
                args.export_reviewed, target, allow_unreviewed=args.allow_unreviewed
            )
            print(output)
            return 0
        if not args.input:
            parser.error("--input is required outside GUI/export/check mode")
        output = args.output or str(Path.cwd() / "apexo_ocr_review.xlsx")

        def progress(message: str, current: int, total: int) -> None:
            print(f"[{current}/{total}] {message}", flush=True)

        result = run_pipeline(args.input, output, config, progress=progress)
        print(result.output_path)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


def run_self_test() -> dict[str, object]:
    with tempfile.TemporaryDirectory(prefix="apexo_ocr_selftest_") as temp_dir:
        root = Path(temp_dir)
        image_path = root / "synthetic.png"
        pdf_path = root / "synthetic.pdf"
        workbook_path = root / "review.xlsx"
        csv_path = root / "patients_import.csv"

        image = Image.new("RGB", (1200, 1700), "white")
        draw = ImageDraw.Draw(image)
        try:
            font = ImageFont.truetype("arial.ttf", 34)
        except OSError:
            font = ImageFont.load_default()
        draw.text((80, 80), "SYNTHETIC OCR SELF TEST", fill="black", font=font)
        image.save(image_path)
        image.save(pdf_path, "PDF", resolution=150)
        rendered = list(iter_document_pages(pdf_path, dpi=160))
        if len(rendered) != 1 or rendered[0].image.width < 100:
            raise RuntimeError("PDF rendering self-test failed")
        rendered[0].image.close()

        record = OcrRecord(
            source_file=image_path.name,
            source_page=1,
            source_sha256="0" * 64,
            engine="self-test",
            values={
                "last_name": "SYNTHETIC",
                "first_name": "PATIENT",
                "registration_date_raw": "01/01/2026",
                "registration_date": "2026-01-01",
            },
        )
        create_review_workbook(
            [record],
            workbook_path,
            batch_name="SELF_TEST",
            requested_engine="self-test",
            selected_engine="self-test",
            model="",
        )
        workbook = load_workbook(workbook_path)
        review = workbook["OCR_Review"]
        headers = [review.cell(1, column).value for column in range(1, review.max_column + 1)]
        review.cell(2, headers.index("review_status") + 1).value = REVIEWED
        workbook.save(workbook_path)
        workbook.close()
        export_reviewed_csv(workbook_path, csv_path)
        csv_report = load_reviewed_csv(csv_path)
        if not csv_report.valid:
            raise RuntimeError("Reviewed CSV validation self-test failed")
        with csv_path.open("r", encoding="utf-8-sig") as stream:
            line_count = sum(1 for _ in stream)
        if line_count != 2:
            raise RuntimeError("CSV self-test failed")
        return {
            "ok": True,
            "app": APP_NAME,
            "version": APP_VERSION,
            "pdf_pages": len(rendered),
            "workbook_sheets": [
                "README",
                "OCR_Review",
                "Import_Preview",
                "Validation_Report",
                "Registration_Dates",
            ],
            "csv_rows": line_count - 1,
            "reviewed_csv_rows": len(csv_report.rows),
            "privacy_boundary": "loopback-only",
        }


def _run_csv_command(args: argparse.Namespace) -> int:
    report = load_reviewed_csv(args.reviewed_csv)
    if not report.valid:
        print(json.dumps(report.safe_summary(), ensure_ascii=False, indent=2))
        return 2
    if not args.target:
        print(json.dumps(report.safe_summary(), ensure_ascii=False, indent=2))
        return 0
    if args.target == "dentalwin":
        if not args.database:
            raise ValueError("--database is required for DentalWin.")
        plan = dry_run_dentalwin(report, args.database)
        if not args.commit:
            print(json.dumps(plan.result, ensure_ascii=False, indent=2))
            return 0
        _confirm_csv_hash(args.confirm, report.source_sha256)
        result = import_dentalwin(report, plan)
    else:
        if not args.apexo_url or not args.apexo_email or not args.password_file:
            raise ValueError("--apexo-url, --apexo-email and --password-file are required for Apexo.")
        password_path = Path(args.password_file).expanduser().resolve()
        password = password_path.read_text(encoding="utf-8-sig").rstrip("\r\n")
        plan = dry_run_apexo(report, args.apexo_url, args.apexo_email, password)
        if not args.commit:
            print(json.dumps(plan.result, ensure_ascii=False, indent=2))
            return 0
        _confirm_csv_hash(args.confirm, report.source_sha256)
        result = import_apexo(report, plan, args.apexo_email, password)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def _confirm_csv_hash(value: str | None, source_sha256: str) -> None:
    expected = source_sha256[:12]
    if value != expected:
        raise ValueError(f"Commit requires --confirm {expected} from this validated CSV.")


def _hide_console() -> None:
    if os.name != "nt":
        return
    try:
        import ctypes

        window = ctypes.windll.kernel32.GetConsoleWindow()
        if window:
            ctypes.windll.user32.ShowWindow(window, 0)
    except Exception:
        pass


def run_gui_smoke_test() -> None:
    """Initialize the packaged Tcl/Tk runtime without showing a window."""
    import tkinter

    root = tkinter.Tk()
    root.withdraw()
    root.update_idletasks()
    root.destroy()


def _configure_console_encoding() -> None:
    """Keep Greek status/error text printable in Windows consoles and pipes."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass


if __name__ == "__main__":
    raise SystemExit(main())
