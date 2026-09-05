from __future__ import annotations

import ipaddress
from urllib.parse import urlparse


class PrivacyBoundaryError(ValueError):
    pass


def validate_loopback_endpoint(endpoint: str) -> str:
    """Return a normalized Ollama base URL, rejecting every remote host."""
    candidate = endpoint.strip().rstrip("/")
    parsed = urlparse(candidate)
    if parsed.scheme != "http":
        raise PrivacyBoundaryError("Το local OCR endpoint πρέπει να χρησιμοποιεί http.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise PrivacyBoundaryError("Το local OCR endpoint δεν πρέπει να περιέχει credentials ή query.")
    if parsed.path not in ("", "/"):
        raise PrivacyBoundaryError("Δώσε μόνο τη βασική local διεύθυνση του Ollama.")
    host = (parsed.hostname or "").lower()
    if host == "localhost":
        pass
    else:
        try:
            if not ipaddress.ip_address(host).is_loopback:
                raise PrivacyBoundaryError(
                    "Απορρίφθηκε μη τοπικό OCR endpoint. Τα scans επιτρέπεται να σταλούν μόνο στο ίδιο PC."
                )
        except ValueError as exc:
            if isinstance(exc, PrivacyBoundaryError):
                raise
            raise PrivacyBoundaryError(
                "Απορρίφθηκε μη τοπικό OCR endpoint. Χρησιμοποίησε 127.0.0.1 ή localhost."
            ) from exc
    if parsed.port is None:
        raise PrivacyBoundaryError("Το local OCR endpoint χρειάζεται port, συνήθως 11434.")
    return candidate
