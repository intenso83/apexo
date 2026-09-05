from __future__ import annotations

import hashlib
from collections.abc import Iterator, Sequence
from pathlib import Path

from PIL import Image, ImageOps

from .constants import SUPPORTED_EXTENSIONS
from .models import PageZones, RenderedPage

Image.MAX_IMAGE_PIXELS = 100_000_000


class DocumentError(RuntimeError):
    pass


def discover_inputs(paths: Sequence[str | Path], recursive: bool = False) -> list[Path]:
    found: list[Path] = []
    for candidate in paths:
        path = Path(candidate).expanduser().resolve()
        if path.is_file():
            if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                raise DocumentError(f"Μη υποστηριζόμενο αρχείο: {path.name}")
            found.append(path)
            continue
        if path.is_dir():
            iterator = path.rglob("*") if recursive else path.glob("*")
            found.extend(
                item.resolve()
                for item in iterator
                if item.is_file() and item.suffix.lower() in SUPPORTED_EXTENSIONS
            )
            continue
        raise DocumentError(f"Δεν βρέθηκε input: {path}")
    return sorted(set(found), key=lambda item: str(item).casefold())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def iter_document_pages(path: Path, dpi: int = 260) -> Iterator[RenderedPage]:
    source_hash = sha256_file(path)
    if path.suffix.lower() == ".pdf":
        try:
            import pypdfium2 as pdfium
        except ImportError as exc:
            raise DocumentError("Λείπει το ενσωματωμένο PDF renderer.") from exc
        try:
            document = pdfium.PdfDocument(str(path))
        except Exception as exc:
            raise DocumentError(f"Δεν άνοιξε το PDF: {path.name}") from exc
        try:
            scale = max(1.0, float(dpi) / 72.0)
            for index in range(len(document)):
                page = document[index]
                try:
                    bitmap = page.render(scale=scale, rotation=0)
                    try:
                        image = bitmap.to_pil().convert("RGB").copy()
                    finally:
                        bitmap.close()
                finally:
                    page.close()
                yield RenderedPage(path, index + 1, source_hash, image)
        finally:
            document.close()
        return

    try:
        opened = Image.open(path)
    except Exception as exc:
        raise DocumentError(f"Δεν άνοιξε η εικόνα: {path.name}") from exc
    try:
        page_number = 0
        while True:
            page_number += 1
            opened.seek(page_number - 1)
            image = ImageOps.exif_transpose(opened).convert("RGB").copy()
            yield RenderedPage(path, page_number, source_hash, image)
            try:
                opened.seek(page_number)
            except EOFError:
                break
    finally:
        opened.close()


def contact_zones(image: Image.Image) -> PageZones:
    """Crop only the administrative zones, avoiding the medical questionnaire."""
    width, height = image.size
    contact = image.crop((0, 0, width, max(1, int(height * 0.40))))
    footer = image.crop((0, int(height * 0.72), width, height))
    return PageZones(contact=contact, footer=footer)


def fit_for_vision(image: Image.Image, max_side: int = 2600) -> Image.Image:
    result = image.convert("RGB")
    if max(result.size) <= max_side:
        return result.copy()
    ratio = max_side / max(result.size)
    size = (max(1, int(result.width * ratio)), max(1, int(result.height * ratio)))
    return result.resize(size, Image.Resampling.LANCZOS)
