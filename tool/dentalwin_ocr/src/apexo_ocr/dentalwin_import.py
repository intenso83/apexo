from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .csv_contract import CsvValidationReport, load_reviewed_csv


PLAN_MAX_AGE_SECONDS = 30 * 60


class DentalWinImportError(RuntimeError):
    pass


@dataclass(frozen=True)
class DentalWinPlan:
    csv_path: Path
    csv_sha256: str
    database_path: Path
    database_sha256: str
    powershell_path: Path
    created_monotonic: float
    result: dict[str, Any]

    @property
    def can_import(self) -> bool:
        return bool(self.result.get("ok") and self.result.get("can_import"))


def dry_run_dentalwin(
    csv_report: CsvValidationReport, database_path: str | Path
) -> DentalWinPlan:
    if not csv_report.valid:
        raise DentalWinImportError("Το CSV έχει validation errors και δεν μπορεί να γίνει dry run.")
    database = _validate_database_path(database_path)
    failures: list[str] = []
    for powershell in _powershell_candidates():
        try:
            result = _run_bridge(
                powershell,
                mode="DryRun",
                database=database,
                csv_report=csv_report,
            )
        except DentalWinImportError as exc:
            failures.append(str(exc))
            continue
        if not result.get("ok"):
            failures.append(str(result.get("error") or "Άγνωστο DentalWin dry-run error."))
            continue
        return DentalWinPlan(
            csv_path=csv_report.source_path,
            csv_sha256=csv_report.source_sha256,
            database_path=database,
            database_sha256=str(result["database_sha256"]),
            powershell_path=powershell,
            created_monotonic=time.monotonic(),
            result=result,
        )
    detail = failures[-1] if failures else "Δεν βρέθηκε Windows PowerShell."
    raise DentalWinImportError(detail)


def import_dentalwin(csv_report: CsvValidationReport, plan: DentalWinPlan) -> dict[str, Any]:
    _validate_live_plan(csv_report, plan)
    result = _run_bridge(
        plan.powershell_path,
        mode="Import",
        database=plan.database_path,
        csv_report=csv_report,
        expected_database_sha256=plan.database_sha256,
    )
    if not result.get("ok"):
        raise DentalWinImportError(str(result.get("error") or "Το DentalWin import απέτυχε."))
    return result


def write_target_audit(result: dict[str, Any], path: str | Path) -> Path:
    target = Path(path).expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.stem}-", suffix=".json", dir=target.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        temporary.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    return target


def _validate_live_plan(csv_report: CsvValidationReport, plan: DentalWinPlan) -> None:
    if not plan.can_import:
        raise DentalWinImportError("Το DentalWin dry run δεν ενέκρινε importable rows.")
    if time.monotonic() - plan.created_monotonic > PLAN_MAX_AGE_SECONDS:
        raise DentalWinImportError("Το DentalWin dry run έληξε. Εκτέλεσε νέο dry run.")
    refreshed = load_reviewed_csv(csv_report.source_path)
    if not refreshed.valid or refreshed.source_sha256 != plan.csv_sha256:
        raise DentalWinImportError("Το CSV άλλαξε μετά το DentalWin dry run.")
    if plan.database_path != _validate_database_path(plan.database_path):
        raise DentalWinImportError("Άλλαξε το DentalWin database path.")


def _validate_database_path(path: str | Path) -> Path:
    database = Path(path).expanduser().resolve()
    if not database.is_file():
        raise DentalWinImportError("Η DentalWin database δεν βρέθηκε.")
    if database.suffix.lower() not in {".mdb", ".accdb"}:
        raise DentalWinImportError("Η DentalWin database πρέπει να είναι .mdb ή .accdb.")
    return database


def _powershell_candidates() -> list[Path]:
    candidates: list[Path] = []
    windows = Path(os.environ.get("WINDIR", r"C:\Windows"))
    for candidate in (
        windows / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
        windows / "SysWOW64" / "WindowsPowerShell" / "v1.0" / "powershell.exe",
    ):
        if candidate.is_file() and candidate not in candidates:
            candidates.append(candidate)
    discovered = shutil.which("powershell.exe")
    if discovered:
        candidate = Path(discovered).resolve()
        if candidate not in candidates:
            candidates.append(candidate)
    return candidates


def _bridge_script() -> Path:
    if getattr(sys, "frozen", False):
        root = Path(getattr(sys, "_MEIPASS"))
        script = root / "resources" / "DentalWinCsvBridge.ps1"
    else:
        script = Path(__file__).resolve().parents[2] / "resources" / "DentalWinCsvBridge.ps1"
    if not script.is_file():
        raise DentalWinImportError("Λείπει το embedded DentalWin CSV bridge.")
    return script


def _run_bridge(
    powershell: Path,
    *,
    mode: str,
    database: Path,
    csv_report: CsvValidationReport,
    expected_database_sha256: str = "",
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="apexo_dentalwin_bridge_") as directory:
        result_path = Path(directory) / "result.json"
        command = [
            str(powershell),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(_bridge_script()),
            "-Mode",
            mode,
            "-DatabasePath",
            str(database),
            "-CsvPath",
            str(csv_report.source_path),
            "-ExpectedCsvSha256",
            csv_report.source_sha256,
            "-ResultPath",
            str(result_path),
        ]
        if expected_database_sha256:
            command.extend(["-ExpectedDatabaseSha256", expected_database_sha256])
        try:
            completed = subprocess.run(
                command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=180,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise DentalWinImportError("Δεν εκτελέστηκε το DentalWin bridge.") from exc
        if not result_path.is_file():
            detail = completed.stderr.decode(errors="replace").strip()
            raise DentalWinImportError(detail or "Το DentalWin bridge δεν επέστρεψε αποτέλεσμα.")
        try:
            result = json.loads(result_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise DentalWinImportError("Το DentalWin bridge επέστρεψε μη έγκυρο αποτέλεσμα.") from exc
        if not isinstance(result, dict):
            raise DentalWinImportError("Το DentalWin bridge επέστρεψε μη έγκυρο αποτέλεσμα.")
        return result
