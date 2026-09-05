from __future__ import annotations

import base64
import hashlib
import json
import re
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .csv_contract import (
    CsvPatient,
    CsvValidationReport,
    load_reviewed_csv,
    patient_duplicate_keys,
)
from .validation import digits, fold


PLAN_MAX_AGE_SECONDS = 30 * 60


class ApexoImportError(RuntimeError):
    pass


@dataclass(frozen=True)
class ApexoPlan:
    csv_path: Path
    csv_sha256: str
    server_url: str
    target_fingerprint: str
    created_monotonic: float
    result: dict[str, Any]

    @property
    def can_import(self) -> bool:
        return bool(self.result.get("ok") and self.result.get("can_import"))


def validate_apexo_url(value: str) -> str:
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ApexoImportError("Το Apexo URL πρέπει να είναι πλήρες http(s) URL.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ApexoImportError("Το Apexo URL δεν επιτρέπει credentials, query ή fragment.")
    if parsed.path not in {"", "/"}:
        raise ApexoImportError("Το Apexo/PocketBase URL πρέπει να δείχνει στο server root.")
    host = parsed.hostname.lower()
    loopback = host in {"localhost", "127.0.0.1", "::1"}
    if parsed.scheme != "https" and not loopback:
        raise ApexoImportError("Remote Apexo import επιτρέπεται μόνο μέσω HTTPS.")
    port = f":{parsed.port}" if parsed.port else ""
    display_host = f"[{host}]" if ":" in host else host
    return f"{parsed.scheme}://{display_host}{port}"


def dry_run_apexo(
    csv_report: CsvValidationReport,
    server_url: str,
    email: str,
    password: str,
) -> ApexoPlan:
    if not csv_report.valid:
        raise ApexoImportError("Το CSV έχει validation errors και δεν μπορεί να γίνει dry run.")
    server = validate_apexo_url(server_url)
    token = _authenticate(server, email, password)
    records = _fetch_patient_records(server, token)
    target_fingerprint = _target_fingerprint(records)
    analysis = _analyze_rows(csv_report, records)
    result: dict[str, Any] = {
        "ok": True,
        "mode": "dry_run",
        "server": server,
        "csv_sha256": csv_report.source_sha256,
        "target_fingerprint": target_fingerprint,
        "target_patient_count": len(records),
        "row_count": len(csv_report.rows),
        "importable_count": analysis["importable_count"],
        "duplicate_count": analysis["duplicate_count"],
        "already_imported_count": analysis["already_imported_count"],
        "can_import": analysis["importable_count"] > 0,
        "rows": analysis["rows"],
        "contains_patient_values": False,
    }
    return ApexoPlan(
        csv_path=csv_report.source_path,
        csv_sha256=csv_report.source_sha256,
        server_url=server,
        target_fingerprint=target_fingerprint,
        created_monotonic=time.monotonic(),
        result=result,
    )


def import_apexo(
    csv_report: CsvValidationReport,
    plan: ApexoPlan,
    email: str,
    password: str,
) -> dict[str, Any]:
    _validate_live_plan(csv_report, plan)
    token = _authenticate(plan.server_url, email, password)
    records = _fetch_patient_records(plan.server_url, token)
    if _target_fingerprint(records) != plan.target_fingerprint:
        raise ApexoImportError("Το Apexo patient store άλλαξε μετά το dry run. Εκτέλεσε νέο dry run.")
    analysis = _analyze_rows(csv_report, records)
    if analysis["rows"] != plan.result.get("rows"):
        raise ApexoImportError("Το Apexo duplicate plan άλλαξε. Εκτέλεσε νέο dry run.")
    new_row_numbers = {
        int(item["row_number"]) for item in analysis["rows"] if item["status"] == "new"
    }
    if not new_row_numbers:
        raise ApexoImportError("Δεν υπάρχουν νέες γραμμές για Apexo import.")

    created_ids: list[str] = []
    try:
        for patient in csv_report.rows:
            if patient.row_number not in new_row_numbers:
                continue
            record_id = _record_id(csv_report.source_sha256, patient)
            payload = {
                "id": record_id,
                "store": "patients",
                "data": _patient_data(csv_report.source_sha256, patient, record_id),
            }
            response = _request_json(
                plan.server_url,
                "/api/collections/data/records",
                method="POST",
                token=token,
                body=payload,
            )
            if str(response.get("id", "")) != record_id or response.get("store") != "patients":
                raise ApexoImportError("Το Apexo create verification επέστρεψε μη αναμενόμενο record.")
            created_ids.append(record_id)
    except Exception as exc:
        rollback_failures = _rollback_created(plan.server_url, token, created_ids)
        if rollback_failures:
            raise ApexoImportError(
                f"Το Apexo import απέτυχε και {rollback_failures} νέες εγγραφές χρειάζονται χειροκίνητο έλεγχο."
            ) from exc
        if isinstance(exc, ApexoImportError):
            raise
        raise ApexoImportError("Το Apexo import απέτυχε και έγινε rollback των νέων εγγραφών.") from exc

    final_records = _fetch_patient_records(plan.server_url, token)
    final_ids = {str(record.get("id", "")) for record in final_records}
    verified_count = sum(record_id in final_ids for record_id in created_ids)
    if verified_count != len(created_ids):
        raise ApexoImportError("Το post-import Apexo verification απέτυχε.")
    return {
        "ok": True,
        "mode": "import",
        "server": plan.server_url,
        "csv_sha256": csv_report.source_sha256,
        "row_count": len(csv_report.rows),
        "created_count": len(created_ids),
        "verified_count": verified_count,
        "duplicate_skipped_count": analysis["duplicate_count"],
        "already_imported_count": analysis["already_imported_count"],
        "target_patient_count_after": len(final_records),
        "target_fingerprint_after": _target_fingerprint(final_records),
        "rows": analysis["rows"],
        "contains_patient_values": False,
    }


def _validate_live_plan(csv_report: CsvValidationReport, plan: ApexoPlan) -> None:
    if not plan.can_import:
        raise ApexoImportError("Το Apexo dry run δεν ενέκρινε importable rows.")
    if time.monotonic() - plan.created_monotonic > PLAN_MAX_AGE_SECONDS:
        raise ApexoImportError("Το Apexo dry run έληξε. Εκτέλεσε νέο dry run.")
    refreshed = load_reviewed_csv(csv_report.source_path)
    if not refreshed.valid or refreshed.source_sha256 != plan.csv_sha256:
        raise ApexoImportError("Το CSV άλλαξε μετά το Apexo dry run.")


def _authenticate(server: str, email: str, password: str) -> str:
    if not email.strip() or not password:
        raise ApexoImportError("Apexo email και password είναι υποχρεωτικά.")
    failures: list[int] = []
    for collection in ("_superusers", "users"):
        try:
            result = _request_json(
                server,
                f"/api/collections/{collection}/auth-with-password",
                method="POST",
                body={"identity": email.strip(), "password": password},
            )
        except ApexoImportError as exc:
            status = getattr(exc, "http_status", 0)
            failures.append(status)
            continue
        token = str(result.get("token", ""))
        if token:
            return token
    if any(status in {401, 403} for status in failures):
        raise ApexoImportError("Το Apexo login απορρίφθηκε.")
    raise ApexoImportError("Δεν ολοκληρώθηκε το Apexo login.")


def _fetch_patient_records(server: str, token: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    page = 1
    while True:
        query = urllib.parse.urlencode(
            {
                "page": page,
                "perPage": 200,
                "filter": 'store="patients"',
                "fields": "id,store,data,updated",
            }
        )
        response = _request_json(
            server, f"/api/collections/data/records?{query}", method="GET", token=token
        )
        items = response.get("items", [])
        if not isinstance(items, list):
            raise ApexoImportError("Το Apexo patient response δεν είναι έγκυρο.")
        records.extend(item for item in items if isinstance(item, dict) and item.get("store") == "patients")
        total_pages = int(response.get("totalPages", 1) or 1)
        if page >= total_pages:
            return records
        page += 1


def _analyze_rows(
    csv_report: CsvValidationReport, existing_records: list[dict[str, Any]]
) -> dict[str, Any]:
    existing_keys: set[tuple[str, str]] = set()
    records_by_id: dict[str, dict[str, Any]] = {}
    for record in existing_records:
        record_id = str(record.get("id", ""))
        records_by_id[record_id] = record
        existing_keys.update(_record_duplicate_keys(record))

    rows: list[dict[str, Any]] = []
    importable = duplicates = already = 0
    for patient in csv_report.rows:
        record_id = _record_id(csv_report.source_sha256, patient)
        existing = records_by_id.get(record_id)
        if existing is not None and _is_same_import(existing, csv_report.source_sha256, patient):
            status, reasons = "already_imported", ["same_csv_row"]
            already += 1
        else:
            matches = sorted(kind for kind, value in patient_duplicate_keys(patient.values) if (kind, value) in existing_keys)
            if existing is not None:
                matches.append("record_id_conflict")
            if matches:
                status, reasons = "duplicate_skipped", sorted(set(matches))
                duplicates += 1
            else:
                status, reasons = "new", []
                importable += 1
        rows.append({"row_number": patient.row_number, "status": status, "reason_codes": reasons})
    return {
        "rows": rows,
        "importable_count": importable,
        "duplicate_count": duplicates,
        "already_imported_count": already,
    }


def _record_duplicate_keys(record: dict[str, Any]) -> set[tuple[str, str]]:
    data = record.get("data", {})
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except json.JSONDecodeError:
            return set()
    if not isinstance(data, dict):
        return set()
    values = {
        "last_name": str(data.get("surname", "")).strip(),
        "first_name": str(data.get("first_name", "")).strip(),
        "amka": str(data.get("amka", "")).strip(),
        "afm": str(data.get("afm", "")).strip(),
        "email": str(data.get("email", "")).strip().lower(),
        "mobile": "",
        "birth_date": str(data.get("birth_date", "")).strip(),
    }
    keys = patient_duplicate_keys(values)
    for phone in _phones_from_value(data.get("phone", "")):
        keys.add(("mobile", phone))
    contacts = data.get("contacts", [])
    if isinstance(contacts, list):
        for contact in contacts:
            if not isinstance(contact, dict):
                continue
            raw = str(contact.get("normalized_value") or contact.get("raw_value") or "").strip()
            contact_type = str(contact.get("type", ""))
            if contact_type == "email" and raw:
                keys.add(("email", raw.lower()))
            elif contact_type in {"mobile", "phone", "home_phone", "work_phone"}:
                normalized = digits(raw)
                if normalized:
                    keys.add(("mobile", normalized))
    return keys


def _phones_from_value(value: object) -> set[str]:
    if isinstance(value, list):
        candidates = [str(item) for item in value]
    else:
        candidates = re.findall(r"\+?\d[\d\s().-]{7,}\d", str(value))
    return {digits(candidate) for candidate in candidates if 10 <= len(digits(candidate)) <= 15}


def _patient_data(csv_sha256: str, patient: CsvPatient, record_id: str) -> dict[str, Any]:
    values = patient.values
    imported_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    data: dict[str, Any] = {
        "id": record_id,
        "title": f"{values['last_name']} {values['first_name']}".strip(),
        "archived": False,
        "surname": values["last_name"],
        "first_name": values["first_name"],
        "occupation": values["profession"],
        "active_status": "active",
        "address": values["address"],
        "address_line": values["address"],
        "area": values["area"],
        "city": values["city"],
        "postal_code": values["postal_code"],
        "amka": values["amka"],
        "afm": values["afm"],
        "doy": values["doy"],
        "referral_source": values["referrer"],
        "phone": values["mobile"],
        "email": values["email"],
        "legacy_custom_fields": {
            "import_source": "ChatGPT-reviewed-CSV",
            "csv_sha256": csv_sha256,
            "csv_row_sha256": patient.row_sha256,
            "csv_index": patient.source_index,
            "imported_at": imported_at,
        },
        "migration": {
            "source_system": "ChatGPT-reviewed-CSV",
            "csv_sha256": csv_sha256,
            "csv_row_sha256": patient.row_sha256,
            "imported_at": imported_at,
        },
    }
    if values["birth_date"]:
        data["birth_date"] = values["birth_date"]
        data["birth_date_precision"] = "exact"
        data["birth"] = int(values["birth_date"][:4])
    if values["registration_date"]:
        data["registration_date"] = values["registration_date"]
    contacts: list[dict[str, Any]] = []
    for order, (kind, value) in enumerate((("mobile", values["mobile"]), ("email", values["email"]))):
        if not value:
            continue
        normalized = value.lower() if kind == "email" else digits(value)
        contact_id = _short_id(f"{record_id}|{kind}|{order}")
        contacts.append(
            {
                "id": contact_id,
                "type": kind,
                "raw_value": value,
                "normalized_value": normalized,
                "is_primary": len(contacts) == 0,
            }
        )
    if contacts:
        data["contacts"] = contacts
    return data


def _is_same_import(record: dict[str, Any], csv_sha256: str, patient: CsvPatient) -> bool:
    data = record.get("data", {})
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except json.JSONDecodeError:
            return False
    if not isinstance(data, dict):
        return False
    provenance = data.get("legacy_custom_fields", {})
    return bool(
        isinstance(provenance, dict)
        and provenance.get("csv_sha256") == csv_sha256
        and provenance.get("csv_row_sha256") == patient.row_sha256
    )


def _record_id(csv_sha256: str, patient: CsvPatient) -> str:
    return _short_id(f"apexo-reviewed-csv-v1|{csv_sha256}|{patient.row_sha256}")


def _short_id(value: str) -> str:
    digest = hashlib.sha256(value.encode("utf-8")).digest()
    return base64.b32encode(digest).decode("ascii").lower().rstrip("=")[:15]


def _target_fingerprint(records: list[dict[str, Any]]) -> str:
    digest = hashlib.sha256()
    for item in sorted(
        (str(record.get("id", "")), str(record.get("updated", ""))) for record in records
    ):
        digest.update((item[0] + "|" + item[1] + "\n").encode("utf-8"))
    return digest.hexdigest()


def _rollback_created(server: str, token: str, record_ids: list[str]) -> int:
    failures = 0
    for record_id in reversed(record_ids):
        try:
            _request_json(
                server,
                f"/api/collections/data/records/{urllib.parse.quote(record_id)}",
                method="DELETE",
                token=token,
                expect_empty=True,
            )
        except ApexoImportError:
            failures += 1
    return failures


def _request_json(
    server: str,
    path: str,
    *,
    method: str,
    token: str = "",
    body: dict[str, Any] | None = None,
    expect_empty: bool = False,
) -> dict[str, Any]:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    headers = {"Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = token
    request = urllib.request.Request(server + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(
            request, timeout=20, context=ssl.create_default_context()
        ) as response:
            payload = response.read()
    except urllib.error.HTTPError as exc:
        status = exc.code
        exc.close()
        error = ApexoImportError(f"Το Apexo request απορρίφθηκε (HTTP {status}).")
        setattr(error, "http_status", status)
        raise error from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ApexoImportError("Δεν ήταν δυνατή η ασφαλής σύνδεση με το Apexo server.") from exc
    if expect_empty or not payload:
        return {}
    try:
        parsed = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApexoImportError("Το Apexo server επέστρεψε μη έγκυρο JSON.") from exc
    if not isinstance(parsed, dict):
        raise ApexoImportError("Το Apexo server επέστρεψε μη έγκυρο response.")
    return parsed
