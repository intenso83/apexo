from __future__ import annotations

import os
import queue
import threading
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, simpledialog, ttk

from .apexo_import import ApexoPlan, dry_run_apexo, import_apexo
from .constants import APP_NAME, APP_VERSION
from .csv_contract import CsvValidationReport, load_reviewed_csv, write_safe_report
from .dentalwin_import import (
    DentalWinPlan,
    dry_run_dentalwin,
    import_dentalwin,
    write_target_audit,
)
from .pipeline import PipelineConfig, default_batch_name, run_pipeline, system_status
from .workbook import WorkbookValidationError, export_reviewed_csv


class OcrApplication:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(f"{APP_NAME} {APP_VERSION}")
        self.root.geometry("1000x780")
        self.root.minsize(900, 700)
        self.inputs: list[str] = []
        self.events: queue.Queue[tuple[str, object]] = queue.Queue()
        self.cancel_event = threading.Event()
        self.worker: threading.Thread | None = None
        self.csv_report: CsvValidationReport | None = None
        self.dentalwin_plan: DentalWinPlan | None = None
        self.apexo_plan: ApexoPlan | None = None

        self.import_csv_var = tk.StringVar()
        self.csv_summary_var = tk.StringVar(value="Δεν έχει γίνει validation.")
        self.dentalwin_database_var = tk.StringVar()
        self.apexo_url_var = tk.StringVar()
        self.apexo_email_var = tk.StringVar()
        self.apexo_password_var = tk.StringVar()

        self.input_var = tk.StringVar()
        self.output_var = tk.StringVar()
        self.batch_var = tk.StringVar(value=default_batch_name())
        self.engine_var = tk.StringVar(value="auto")
        self.endpoint_var = tk.StringVar(value="http://127.0.0.1:11434")
        self.model_var = tk.StringVar(value="qwen3-vl:4b-instruct-q4_K_M")
        self.tesseract_var = tk.StringVar()
        self.recursive_var = tk.BooleanVar(value=False)
        self.review_workbook_var = tk.StringVar()
        self.csv_output_var = tk.StringVar()
        self.status_var = tk.StringVar(value="Έτοιμο")

        self._build()
        self._refresh_import_buttons()
        self.root.after(100, self._drain_events)

    def _build(self) -> None:
        outer = ttk.Frame(self.root, padding=14)
        outer.pack(fill="both", expand=True)

        title = ttk.Label(outer, text="Apexo Patient Import Utility", font=("Segoe UI", 18, "bold"))
        title.pack(anchor="w")
        ttk.Label(
            outer,
            text=(
                "Ελεγμένο CSV → ανεξάρτητο dry run → DentalWin ή Apexo import. "
                "Το OCR παραμένει διαθέσιμο ως προαιρετικό εργαλείο."
            ),
            wraplength=850,
        ).pack(anchor="w", pady=(2, 10))

        privacy = tk.Label(
            outer,
            text=(
                "SAFETY: Το CSV δεν αλλάζει ποτέ. Κάθε target απαιτεί νέο dry run· "
                "medical-history fields και αυτόματα merges μπλοκάρονται."
            ),
            bg="#e2f0d9",
            fg="#1f4e32",
            padx=10,
            pady=8,
            anchor="w",
        )
        privacy.pack(fill="x", pady=(0, 10))

        notebook = ttk.Notebook(outer)
        notebook.pack(fill="both", expand=True)
        import_tab = ttk.Frame(notebook, padding=12)
        scan_tab = ttk.Frame(notebook, padding=12)
        export_tab = ttk.Frame(notebook, padding=12)
        notebook.add(import_tab, text="1. Import checked CSV")
        notebook.add(scan_tab, text="2. Optional OCR")
        notebook.add(export_tab, text="3. Export reviewed CSV")
        self._build_import_tab(import_tab)
        self._build_scan_tab(scan_tab)
        self._build_export_tab(export_tab)

        footer = ttk.Frame(outer)
        footer.pack(fill="x", pady=(10, 0))
        self.progress = ttk.Progressbar(footer, mode="indeterminate")
        self.progress.pack(side="left", fill="x", expand=True)
        ttk.Label(footer, textvariable=self.status_var, width=32).pack(side="left", padx=(10, 0))

    def _build_import_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(1, weight=1)
        row = 0
        ttk.Label(
            parent,
            text=(
                "Χρησιμοποίησε μόνο το ήδη ελεγμένο UTF-8 CSV με το συμφωνημένο header. "
                "DentalWin και Apexo είναι δύο ξεχωριστές ενέργειες."
            ),
            wraplength=900,
        ).grid(row=row, column=0, columnspan=3, sticky="w", pady=(0, 10))

        row += 1
        ttk.Label(parent, text="Reviewed CSV").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.import_csv_var).grid(
            row=row, column=1, sticky="ew", padx=8
        )
        ttk.Button(parent, text="Επιλογή…", command=self._choose_import_csv).grid(row=row, column=2)

        row += 1
        validation = ttk.Frame(parent)
        validation.grid(row=row, column=0, columnspan=3, sticky="ew", pady=(4, 10))
        self.validate_csv_button = ttk.Button(
            validation, text="1  Validate CSV", command=self._validate_import_csv
        )
        self.validate_csv_button.pack(side="left")
        ttk.Label(validation, textvariable=self.csv_summary_var).pack(side="left", padx=12)

        row += 1
        dentalwin = ttk.LabelFrame(parent, text="DentalWin V6/V7 (.mdb/.accdb)", padding=10)
        dentalwin.grid(row=row, column=0, columnspan=3, sticky="ew", pady=5)
        dentalwin.columnconfigure(1, weight=1)
        ttk.Label(dentalwin, text="Database copy / live DB").grid(row=0, column=0, sticky="w")
        ttk.Entry(dentalwin, textvariable=self.dentalwin_database_var).grid(
            row=0, column=1, sticky="ew", padx=8
        )
        ttk.Button(dentalwin, text="Επιλογή…", command=self._choose_dentalwin_database).grid(
            row=0, column=2
        )
        ttk.Label(
            dentalwin,
            text=(
                "Το import αρνείται ανοικτή .ldb βάση, δημιουργεί verified backup και γράφει "
                "Customers + CustomerEpikoinonies μέσα σε transaction."
            ),
            wraplength=820,
        ).grid(row=1, column=0, columnspan=3, sticky="w", pady=(6, 8))
        self.dentalwin_dry_button = ttk.Button(
            dentalwin, text="2A  DentalWin dry run", command=self._dentalwin_dry_run
        )
        self.dentalwin_dry_button.grid(row=2, column=1, sticky="e")
        self.dentalwin_import_button = ttk.Button(
            dentalwin,
            text="3A  Import to DentalWin",
            command=self._dentalwin_import,
            state="disabled",
        )
        self.dentalwin_import_button.grid(row=2, column=2, sticky="e", padx=(8, 0))

        row += 1
        apexo = ttk.LabelFrame(parent, text="Apexo fork (PocketBase)", padding=10)
        apexo.grid(row=row, column=0, columnspan=3, sticky="ew", pady=5)
        apexo.columnconfigure(1, weight=1)
        ttk.Label(apexo, text="Server URL").grid(row=0, column=0, sticky="w", pady=3)
        ttk.Entry(apexo, textvariable=self.apexo_url_var).grid(row=0, column=1, columnspan=2, sticky="ew", padx=8)
        ttk.Label(apexo, text="Email").grid(row=1, column=0, sticky="w", pady=3)
        ttk.Entry(apexo, textvariable=self.apexo_email_var).grid(row=1, column=1, sticky="ew", padx=8)
        ttk.Label(apexo, text="Password").grid(row=2, column=0, sticky="w", pady=3)
        ttk.Entry(apexo, textvariable=self.apexo_password_var, show="•").grid(
            row=2, column=1, sticky="ew", padx=8
        )
        ttk.Label(
            apexo,
            text="Remote servers require HTTPS. Passwords and patient values are never written to audit logs.",
            wraplength=820,
        ).grid(row=3, column=0, columnspan=3, sticky="w", pady=(5, 8))
        self.apexo_dry_button = ttk.Button(
            apexo, text="2B  Apexo dry run", command=self._apexo_dry_run
        )
        self.apexo_dry_button.grid(row=4, column=1, sticky="e")
        self.apexo_import_button = ttk.Button(
            apexo, text="3B  Import to Apexo", command=self._apexo_import, state="disabled"
        )
        self.apexo_import_button.grid(row=4, column=2, sticky="e", padx=(8, 0))

        row += 1
        ttk.Label(parent, text="Import log (counts/reason codes only)").grid(
            row=row, column=0, columnspan=3, sticky="w", pady=(8, 0)
        )
        row += 1
        self.import_log = tk.Text(
            parent, height=7, state="disabled", wrap="word", font=("Consolas", 9)
        )
        self.import_log.grid(row=row, column=0, columnspan=3, sticky="nsew", pady=(4, 0))
        parent.rowconfigure(row, weight=1)

    def _build_scan_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(1, weight=1)
        row = 0
        ttk.Label(parent, text="Scans").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.input_var).grid(row=row, column=1, sticky="ew", padx=8)
        buttons = ttk.Frame(parent)
        buttons.grid(row=row, column=2)
        ttk.Button(buttons, text="Αρχεία…", command=self._choose_files).pack(side="left")
        ttk.Button(buttons, text="Φάκελος…", command=self._choose_folder).pack(side="left", padx=(5, 0))

        row += 1
        ttk.Checkbutton(
            parent, text="Συμπερίληψη υποφακέλων", variable=self.recursive_var
        ).grid(row=row, column=1, sticky="w", padx=8)

        row += 1
        ttk.Label(parent, text="Review Excel").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.output_var).grid(row=row, column=1, sticky="ew", padx=8)
        ttk.Button(parent, text="Αποθήκευση…", command=self._choose_output).grid(row=row, column=2)

        row += 1
        ttk.Label(parent, text="Batch name").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.batch_var).grid(row=row, column=1, sticky="ew", padx=8)

        row += 1
        separator = ttk.Separator(parent)
        separator.grid(row=row, column=0, columnspan=3, sticky="ew", pady=10)

        row += 1
        ttk.Label(parent, text="OCR engine").grid(row=row, column=0, sticky="w", pady=5)
        engine_box = ttk.Combobox(
            parent,
            textvariable=self.engine_var,
            values=("auto", "ollama", "tesseract"),
            state="readonly",
        )
        engine_box.grid(row=row, column=1, sticky="w", padx=8)

        row += 1
        ttk.Label(parent, text="Local Ollama").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.endpoint_var).grid(row=row, column=1, sticky="ew", padx=8)

        row += 1
        ttk.Label(parent, text="Vision model").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.model_var).grid(row=row, column=1, sticky="ew", padx=8)

        row += 1
        ttk.Label(parent, text="Tesseract (optional)").grid(row=row, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.tesseract_var).grid(row=row, column=1, sticky="ew", padx=8)
        ttk.Button(parent, text="Επιλογή…", command=self._choose_tesseract).grid(row=row, column=2)

        row += 1
        controls = ttk.Frame(parent)
        controls.grid(row=row, column=0, columnspan=3, sticky="ew", pady=(12, 6))
        self.check_button = ttk.Button(controls, text="Έλεγχος συστήματος", command=self._check_system)
        self.check_button.pack(side="left")
        self.run_button = ttk.Button(controls, text="Έναρξη OCR", command=self._start_ocr)
        self.run_button.pack(side="right")
        self.cancel_button = ttk.Button(
            controls, text="Ακύρωση", command=self.cancel_event.set, state="disabled"
        )
        self.cancel_button.pack(side="right", padx=(0, 8))

        row += 1
        ttk.Label(parent, text="Log (χωρίς patient values)").grid(
            row=row, column=0, columnspan=3, sticky="w"
        )
        row += 1
        self.log = tk.Text(parent, height=11, state="disabled", wrap="word", font=("Consolas", 9))
        self.log.grid(row=row, column=0, columnspan=3, sticky="nsew", pady=(4, 0))
        parent.rowconfigure(row, weight=1)

    def _build_export_tab(self, parent: ttk.Frame) -> None:
        parent.columnconfigure(1, weight=1)
        ttk.Label(
            parent,
            text=(
                "Το export επιτρέπεται μόνο όταν όλες οι included γραμμές έχουν review_status = "
                "ΕΛΕΓΧΘΗΚΕ. Τα medical-history columns παραμένουν υποχρεωτικά κενά/0."
            ),
            wraplength=780,
        ).grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 14))
        ttk.Label(parent, text="Reviewed workbook").grid(row=1, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.review_workbook_var).grid(
            row=1, column=1, sticky="ew", padx=8
        )
        ttk.Button(parent, text="Επιλογή…", command=self._choose_review_workbook).grid(row=1, column=2)
        ttk.Label(parent, text="patients_import.csv").grid(row=2, column=0, sticky="w", pady=5)
        ttk.Entry(parent, textvariable=self.csv_output_var).grid(row=2, column=1, sticky="ew", padx=8)
        ttk.Button(parent, text="Αποθήκευση…", command=self._choose_csv).grid(row=2, column=2)
        ttk.Button(parent, text="Export reviewed CSV", command=self._export_csv).grid(
            row=3, column=2, sticky="e", pady=14
        )

    def _choose_files(self) -> None:
        selected = filedialog.askopenfilenames(
            title="Επιλογή scans",
            filetypes=[
                ("Scans", "*.pdf *.jpg *.jpeg *.png *.tif *.tiff *.bmp *.webp"),
                ("All files", "*.*"),
            ],
        )
        if selected:
            self.inputs = list(selected)
            self.input_var.set(f"{len(selected)} αρχεία")
            self._suggest_output(Path(selected[0]).parent)

    def _choose_import_csv(self) -> None:
        selected = filedialog.askopenfilename(
            title="Reviewed patients CSV",
            filetypes=[("CSV", "*.csv"), ("All files", "*.*")],
        )
        if selected:
            self.import_csv_var.set(selected)
            self.csv_report = None
            self.dentalwin_plan = None
            self.apexo_plan = None
            self.csv_summary_var.set("Χρειάζεται validation.")
            self._refresh_import_buttons()

    def _choose_dentalwin_database(self) -> None:
        selected = filedialog.askopenfilename(
            title="DentalWin database",
            filetypes=[("Access database", "*.mdb *.accdb"), ("All files", "*.*")],
        )
        if selected:
            self.dentalwin_database_var.set(selected)
            self.dentalwin_plan = None
            self._refresh_import_buttons()

    def _validate_import_csv(self) -> None:
        try:
            report = load_reviewed_csv(self.import_csv_var.get())
        except Exception as exc:
            self.csv_report = None
            self.csv_summary_var.set("Validation απέτυχε.")
            self._append_import_log(f"CSV validation failed: {exc}")
            messagebox.showerror(APP_NAME, str(exc))
            self._refresh_import_buttons()
            return
        self.csv_report = report
        self.dentalwin_plan = None
        self.apexo_plan = None
        summary = (
            f"Rows: {len(report.rows)} | errors: {len(report.errors)} | "
            f"warnings: {len(report.warnings)} | SHA-256: {report.source_sha256[:12]}…"
        )
        self.csv_summary_var.set(summary)
        safe_report = report.source_path.parent / "ApexoImportReports" / (
            report.source_path.stem + "-validation.json"
        )
        write_safe_report(report, safe_report)
        self._append_import_log(summary)
        if report.valid:
            messagebox.showinfo(
                APP_NAME,
                f"Το CSV είναι έγκυρο για dry run.\n\nRows: {len(report.rows)}\n"
                f"Audit: {safe_report}",
            )
        else:
            sample = "\n".join(
                f"Row {issue.row_number} / {issue.field}: {issue.code}"
                for issue in report.errors[:12]
            )
            messagebox.showerror(
                APP_NAME,
                f"Το CSV έχει {len(report.errors)} errors και δεν μπορεί να εισαχθεί.\n\n{sample}",
            )
        self._refresh_import_buttons()

    def _current_csv_report(self) -> CsvValidationReport:
        report = load_reviewed_csv(self.import_csv_var.get())
        self.csv_report = report
        if not report.valid:
            raise ValueError("Το CSV έχει validation errors.")
        return report

    def _dentalwin_dry_run(self) -> None:
        try:
            report = self._current_csv_report()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        database = self.dentalwin_database_var.get()
        self._set_busy(True, "DentalWin dry run…")

        def work() -> None:
            try:
                plan = dry_run_dentalwin(report, database)
                self.events.put(("dentalwin_plan", plan))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        self.worker = threading.Thread(target=work, daemon=True)
        self.worker.start()

    def _apexo_dry_run(self) -> None:
        try:
            report = self._current_csv_report()
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        server = self.apexo_url_var.get()
        email = self.apexo_email_var.get()
        password = self.apexo_password_var.get()
        self._set_busy(True, "Apexo dry run…")

        def work() -> None:
            try:
                plan = dry_run_apexo(report, server, email, password)
                self.events.put(("apexo_plan", plan))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        self.worker = threading.Thread(target=work, daemon=True)
        self.worker.start()

    def _dentalwin_import(self) -> None:
        plan = self.dentalwin_plan
        if plan is None or not plan.can_import or self.csv_report is None:
            messagebox.showerror(APP_NAME, "Εκτέλεσε επιτυχημένο DentalWin dry run πρώτα.")
            return
        count = int(plan.result.get("importable_count", 0))
        phrase = simpledialog.askstring(
            APP_NAME,
            f"Θα δημιουργηθούν {count} νέοι ασθενείς στο DentalWin.\n"
            "Τα duplicates θα παραλειφθούν και θα δημιουργηθεί verified backup.\n\n"
            f"Πληκτρολόγησε IMPORT {count} για επιβεβαίωση:",
        )
        if phrase != f"IMPORT {count}":
            return
        report = self.csv_report
        self._set_busy(True, "DentalWin import…")

        def work() -> None:
            try:
                result = import_dentalwin(report, plan)
                audit = self._write_import_audit("dentalwin", result)
                self.events.put(("dentalwin_imported", (result, audit)))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        self.worker = threading.Thread(target=work, daemon=True)
        self.worker.start()

    def _apexo_import(self) -> None:
        plan = self.apexo_plan
        if plan is None or not plan.can_import or self.csv_report is None:
            messagebox.showerror(APP_NAME, "Εκτέλεσε επιτυχημένο Apexo dry run πρώτα.")
            return
        count = int(plan.result.get("importable_count", 0))
        phrase = simpledialog.askstring(
            APP_NAME,
            f"Θα δημιουργηθούν {count} νέοι ασθενείς στο Apexo.\n"
            "Τα duplicates δεν συγχωνεύονται και θα παραλειφθούν.\n\n"
            f"Πληκτρολόγησε IMPORT {count} για επιβεβαίωση:",
        )
        if phrase != f"IMPORT {count}":
            return
        report = self.csv_report
        email = self.apexo_email_var.get()
        password = self.apexo_password_var.get()
        self._set_busy(True, "Apexo import…")

        def work() -> None:
            try:
                result = import_apexo(report, plan, email, password)
                audit = self._write_import_audit("apexo", result)
                self.events.put(("apexo_imported", (result, audit)))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        self.worker = threading.Thread(target=work, daemon=True)
        self.worker.start()

    def _write_import_audit(self, target: str, result: dict[str, object]) -> Path:
        assert self.csv_report is not None
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        path = self.csv_report.source_path.parent / "ApexoImportReports" / (
            f"{self.csv_report.source_path.stem}-{target}-{timestamp}.json"
        )
        return write_target_audit(result, path)

    def _choose_folder(self) -> None:
        selected = filedialog.askdirectory(title="Επιλογή φακέλου scans")
        if selected:
            self.inputs = [selected]
            self.input_var.set(selected)
            self._suggest_output(Path(selected))

    def _suggest_output(self, directory: Path) -> None:
        if not self.output_var.get():
            self.output_var.set(str(directory / f"{self.batch_var.get()}_ocr_review.xlsx"))

    def _choose_output(self) -> None:
        selected = filedialog.asksaveasfilename(
            title="Review Excel",
            defaultextension=".xlsx",
            filetypes=[("Excel workbook", "*.xlsx")],
        )
        if selected:
            self.output_var.set(selected)

    def _choose_tesseract(self) -> None:
        selected = filedialog.askopenfilename(
            title="tesseract.exe", filetypes=[("Tesseract", "tesseract.exe"), ("EXE", "*.exe")]
        )
        if selected:
            self.tesseract_var.set(selected)

    def _choose_review_workbook(self) -> None:
        selected = filedialog.askopenfilename(
            title="Reviewed workbook", filetypes=[("Excel workbook", "*.xlsx")]
        )
        if selected:
            self.review_workbook_var.set(selected)
            self.csv_output_var.set(str(Path(selected).parent / "patients_import.csv"))

    def _choose_csv(self) -> None:
        selected = filedialog.asksaveasfilename(
            title="patients_import.csv",
            initialfile="patients_import.csv",
            defaultextension=".csv",
            filetypes=[("CSV", "*.csv")],
        )
        if selected:
            self.csv_output_var.set(selected)

    def _config(self) -> PipelineConfig:
        return PipelineConfig(
            engine=self.engine_var.get(),
            endpoint=self.endpoint_var.get(),
            model=self.model_var.get(),
            tesseract_path=self.tesseract_var.get() or None,
            recursive=self.recursive_var.get(),
            batch_name=self.batch_var.get(),
        )

    def _check_system(self) -> None:
        self._set_busy(True, "Έλεγχος local OCR engines…")

        def work() -> None:
            try:
                self.events.put(("system", system_status(self._config())))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        threading.Thread(target=work, daemon=True).start()

    def _start_ocr(self) -> None:
        if not self.inputs:
            messagebox.showerror(APP_NAME, "Επίλεξε scans ή φάκελο scans.")
            return
        if not self.output_var.get():
            messagebox.showerror(APP_NAME, "Επίλεξε review Excel output.")
            return
        self.cancel_event.clear()
        self._set_busy(True, "OCR σε εξέλιξη…")

        def on_progress(message: str, current: int, total: int) -> None:
            self.events.put(("log", message))
            self.events.put(("status", message))

        def work() -> None:
            try:
                result = run_pipeline(
                    self.inputs,
                    self.output_var.get(),
                    self._config(),
                    progress=on_progress,
                    cancel_event=self.cancel_event,
                )
                self.events.put(("complete", result.output_path))
            except Exception as exc:
                self.events.put(("error", str(exc)))
            finally:
                self.events.put(("idle", None))

        self.worker = threading.Thread(target=work, daemon=True)
        self.worker.start()

    def _export_csv(self) -> None:
        try:
            output = export_reviewed_csv(
                self.review_workbook_var.get(), self.csv_output_var.get(), allow_unreviewed=False
            )
        except (WorkbookValidationError, OSError, ValueError) as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        messagebox.showinfo(APP_NAME, f"Έτοιμο:\n{output}\n\nΤρέξε πρώτα το DentalWin dry run.")

    def _set_busy(self, busy: bool, message: str = "Έτοιμο") -> None:
        self.status_var.set(message)
        state = "disabled" if busy else "normal"
        self.run_button.configure(state=state)
        self.check_button.configure(state=state)
        self.validate_csv_button.configure(state=state)
        self.dentalwin_dry_button.configure(state=state)
        self.apexo_dry_button.configure(state=state)
        self.cancel_button.configure(state="normal" if busy else "disabled")
        if busy:
            self.dentalwin_import_button.configure(state="disabled")
            self.apexo_import_button.configure(state="disabled")
            self.progress.start(12)
        else:
            self.progress.stop()
            self._refresh_import_buttons()

    def _refresh_import_buttons(self) -> None:
        valid = self.csv_report is not None and self.csv_report.valid
        self.dentalwin_dry_button.configure(state="normal" if valid else "disabled")
        self.apexo_dry_button.configure(state="normal" if valid else "disabled")
        self.dentalwin_import_button.configure(
            state="normal"
            if self.dentalwin_plan is not None and self.dentalwin_plan.can_import
            else "disabled"
        )
        self.apexo_import_button.configure(
            state="normal"
            if self.apexo_plan is not None and self.apexo_plan.can_import
            else "disabled"
        )

    def _append_log(self, message: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", message + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _append_import_log(self, message: str) -> None:
        self.import_log.configure(state="normal")
        self.import_log.insert("end", message + "\n")
        self.import_log.see("end")
        self.import_log.configure(state="disabled")

    def _drain_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "log":
                    self._append_log(str(payload))
                elif kind == "status":
                    self.status_var.set(str(payload))
                elif kind == "system":
                    status = payload if isinstance(payload, dict) else {}
                    ollama = status.get("ollama", {})
                    tesseract = status.get("tesseract", {})
                    message = (
                        f"Ollama: {ollama.get('message', '')}\n"
                        f"Tesseract: {tesseract.get('message', '')}\n"
                        "Privacy boundary: loopback-only"
                    )
                    self._append_log(message.replace("\n", " | "))
                    messagebox.showinfo(APP_NAME, message)
                elif kind == "complete":
                    output = Path(str(payload))
                    self.review_workbook_var.set(str(output))
                    self.csv_output_var.set(str(output.parent / "patients_import.csv"))
                    messagebox.showinfo(
                        APP_NAME,
                        f"Το review workbook δημιουργήθηκε:\n{output}\n\nΔεν είναι import-ready πριν τον ανθρώπινο έλεγχο.",
                    )
                elif kind == "dentalwin_plan":
                    self.dentalwin_plan = payload if isinstance(payload, DentalWinPlan) else None
                    if self.dentalwin_plan is not None:
                        result = self.dentalwin_plan.result
                        message = (
                            f"DentalWin dry run: new={result.get('importable_count', 0)}, "
                            f"duplicates skipped={result.get('duplicate_count', 0)}, "
                            f"locked={result.get('database_locked', False)}"
                        )
                        self._append_import_log(message)
                        messagebox.showinfo(APP_NAME, message)
                elif kind == "apexo_plan":
                    self.apexo_plan = payload if isinstance(payload, ApexoPlan) else None
                    if self.apexo_plan is not None:
                        result = self.apexo_plan.result
                        message = (
                            f"Apexo dry run: new={result.get('importable_count', 0)}, "
                            f"duplicates skipped={result.get('duplicate_count', 0)}, "
                            f"already imported={result.get('already_imported_count', 0)}"
                        )
                        self._append_import_log(message)
                        messagebox.showinfo(APP_NAME, message)
                elif kind in {"dentalwin_imported", "apexo_imported"}:
                    result, audit = payload
                    target = "DentalWin" if kind == "dentalwin_imported" else "Apexo"
                    message = (
                        f"{target} import complete: created={result.get('created_count', 0)}, "
                        f"verified={result.get('verified_count', 0)} | Audit: {audit}"
                    )
                    self._append_import_log(message)
                    self.dentalwin_plan = None if kind == "dentalwin_imported" else self.dentalwin_plan
                    self.apexo_plan = None if kind == "apexo_imported" else self.apexo_plan
                    messagebox.showinfo(APP_NAME, message)
                elif kind == "error":
                    self._append_import_log("ERROR: " + str(payload))
                    messagebox.showerror(APP_NAME, str(payload))
                elif kind == "idle":
                    self._set_busy(False)
        except queue.Empty:
            pass
        self.root.after(100, self._drain_events)


def launch_gui() -> None:
    root = tk.Tk()
    try:
        ttk.Style(root).theme_use("vista")
    except tk.TclError:
        pass
    OcrApplication(root)
    root.mainloop()
