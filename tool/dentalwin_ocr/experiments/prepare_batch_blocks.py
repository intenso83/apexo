from __future__ import annotations

import argparse
import csv
import hashlib
import json
import secrets
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageOps
import numpy as np
from PIL import ImageFilter


REFERENCE_SIZE = (1664, 2400)
REFERENCE_BLOCKS: tuple[tuple[str, tuple[int, int, int, int]], ...] = (
    ("full_name", (65, 450, 1580, 500)),
    ("address", (65, 480, 760, 535)),
    ("mobile", (580, 515, 1090, 570)),
    ("email", (1040, 465, 1660, 525)),
    ("registration_date", (100, 2050, 800, 2130)),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare independently identifiable OCR blocks for a rendered PDF batch."
    )
    parser.add_argument("--render-manifest", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--reference-page", default=15, type=int)
    parser.add_argument("--tsv-dir", type=Path)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def aligned_box(
    box: tuple[int, int, int, int],
    width: int,
    height: int,
    phase_x: float,
    phase_y: float,
) -> tuple[int, int, int, int]:
    reference_width, reference_height = REFERENCE_SIZE
    left, top, right, bottom = box
    return (
        round((left - phase_x) * width / reference_width),
        round((top - phase_y) * height / reference_height),
        round((right - phase_x) * width / reference_width),
        round((bottom - phase_y) * height / reference_height),
    )


def registration_array(image: Image.Image) -> np.ndarray:
    normalized = ImageOps.autocontrast(
        image.convert("L").resize((416, 600), Image.Resampling.LANCZOS)
    )
    raw = np.asarray(normalized, dtype=np.float32)
    blurred = np.asarray(normalized.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32)
    return raw - blurred


def phase_shift(reference: np.ndarray, image: Image.Image) -> tuple[float, float, float]:
    candidate = registration_array(image)
    correlation = np.fft.ifft2(
        np.fft.fft2(reference) * np.conj(np.fft.fft2(candidate))
    )
    magnitude = np.abs(correlation)
    y, x = np.unravel_index(np.argmax(magnitude), magnitude.shape)
    if y > magnitude.shape[0] // 2:
        y -= magnitude.shape[0]
    if x > magnitude.shape[1] // 2:
        x -= magnitude.shape[1]
    score = float(
        magnitude.max()
        / np.sqrt((reference * reference).sum() * (candidate * candidate).sum())
    )
    return x * 4.0, y * 4.0, score


def normalized_token(value: str) -> str:
    return "".join(character for character in value.upper() if character.isalnum())


def load_anchors(tsv_path: Path) -> dict[str, tuple[int, int, int, int]]:
    anchors: dict[str, tuple[int, int, int, int]] = {}
    with tsv_path.open("r", encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream, delimiter="\t", quoting=csv.QUOTE_NONE):
            text = normalized_token(row.get("text", ""))
            if not text:
                continue
            box = tuple(int(row[name]) for name in ("left", "top", "width", "height"))
            top = box[1]
            if "ΟΝΟΜΑΤΕΠΩΝΥΜΟ" in text and "full_name" not in anchors:
                anchors["full_name"] = box
            elif "ΔΙΕΥΘΥΝΣΗ" in text and "address" not in anchors:
                anchors["address"] = box
            elif ("ΚΙΝΗΤΟ" in text or "KINHTO" in text) and "mobile" not in anchors:
                anchors["mobile"] = box
            elif "MAIL" in text and "email" not in anchors:
                anchors["email"] = box
            elif top > 1500 and (
                "ΗΜΕΡΟΜΗΝΙΑ" in text or "HMEPOMHNIA" in text
            ):
                anchors["registration_date"] = box
    return anchors


def anchor_boxes(
    anchors: dict[str, tuple[int, int, int, int]], width: int, height: int
) -> dict[str, tuple[int, int, int, int]]:
    address = anchors.get("address")
    name = anchors.get("full_name")
    mobile = anchors.get("mobile")
    email = anchors.get("email")
    date = anchors.get("registration_date")

    address_top = address[1] if address else (name[1] + 38 if name else None)
    if address_top is None:
        raise ValueError("Could not locate the personal-details rows")
    name_left = name[0] if name else (address[0] if address else round(width * 0.07))
    name_top = name[1] if name else address_top - 38
    address_left = address[0] if address else name_left
    mobile_left = mobile[0] if mobile else round(width * 0.36)
    mobile_top = mobile[1] if mobile else address_top + 35
    email_left = email[0] if email else round(width * 0.65)
    email_top = email[1] if email else address_top - 8

    if date is None:
        raise ValueError("Could not locate the lower-left registration date")
    date_left, date_top, _, date_height = date
    return {
        "full_name": (
            max(0, name_left - 20),
            max(0, name_top - 15),
            max(name_left + 300, email_left - 25),
            min(height, name_top + 45),
        ),
        "address": (
            max(0, address_left - 20),
            max(0, address_top - 15),
            min(width, email_left - 25),
            min(height, address_top + 47),
        ),
        "mobile": (
            max(0, mobile_left - 20),
            max(0, mobile_top - 15),
            min(width, email_left - 25),
            min(height, mobile_top + 47),
        ),
        "email": (
            max(0, email_left - 20),
            max(0, email_top - 15),
            width,
            min(height, email_top + 50),
        ),
        "registration_date": (
            max(0, date_left - 30),
            max(0, date_top - 25),
            min(width, date_left + 700),
            min(height, date_top + max(75, date_height + 25)),
        ),
    }


def prepare_block(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = image.crop(box).convert("RGB")
    crop = ImageOps.expand(crop, border=24, fill="white")
    crop = ImageEnhance.Contrast(crop).enhance(1.12)
    crop = ImageEnhance.Sharpness(crop).enhance(1.35)
    return crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.LANCZOS)


def make_contact_sheet(field: str, items: list[tuple[int, Image.Image]], path: Path) -> None:
    columns = 2
    cell_width, cell_height = 1020, 150
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_width, rows * cell_height), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 6), field, fill="black")
    for index, (page, block) in enumerate(items):
        cell_x = index % columns * cell_width
        cell_y = index // columns * cell_height
        thumbnail = ImageOps.contain(block, (900, 112), Image.Resampling.LANCZOS)
        sheet.paste(thumbnail, (cell_x + 105, cell_y + 30))
        draw.text((cell_x + 12, cell_y + 65), f"Page {page:02d}", fill="black")
        thumbnail.close()
        block.close()
    sheet.save(path, format="PNG", optimize=True)
    sheet.close()


def main() -> int:
    args = parse_args()
    render_manifest_path = args.render_manifest.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    tsv_dir = args.tsv_dir.resolve(strict=True) if args.tsv_dir else None
    blocks_dir = output_dir / "blocks"
    previews_dir = output_dir / "previews"
    blocks_dir.mkdir(parents=True, exist_ok=True)
    previews_dir.mkdir(parents=True, exist_ok=True)

    render_manifest: dict[str, Any] = json.loads(
        render_manifest_path.read_text(encoding="utf-8")
    )
    reference_info = next(
        (item for item in render_manifest["pages"] if item["page"] == args.reference_page),
        None,
    )
    if reference_info is None:
        raise ValueError(f"Reference page {args.reference_page} was not rendered")
    with Image.open(Path(reference_info["image"]).resolve(strict=True)) as opened:
        reference_image = opened.convert("RGB")
    reference_registration = registration_array(reference_image)
    reference_image.close()
    manifest_blocks: list[dict[str, Any]] = []
    preview_items: dict[str, list[tuple[int, Image.Image]]] = defaultdict(list)
    alignments: list[dict[str, Any]] = []

    for page_info in render_manifest["pages"]:
        page_number = int(page_info["page"])
        page_path = Path(page_info["image"]).resolve(strict=True)
        with Image.open(page_path) as opened:
            image = opened.convert("RGB")
        phase_x, phase_y, score = phase_shift(reference_registration, image)
        alignments.append(
            {
                "page": page_number,
                "phase_x": phase_x,
                "phase_y": phase_y,
                "score": score,
            }
        )
        detected_anchors: dict[str, tuple[int, int, int, int]] = {}
        detected_boxes: dict[str, tuple[int, int, int, int]] = {}
        if tsv_dir:
            detected_anchors = load_anchors(tsv_dir / f"page-{page_number:02d}.tsv")
            detected_boxes = anchor_boxes(detected_anchors, image.width, image.height)
        for field, reference_box in REFERENCE_BLOCKS:
            box = detected_boxes.get(field) or aligned_box(
                reference_box, image.width, image.height, phase_x, phase_y
            )
            block_id = secrets.token_hex(12).upper()
            block_path = blocks_dir / f"{block_id}.png"
            prepared = prepare_block(image, box)
            prepared.save(block_path, format="PNG", optimize=True)
            preview_items[field].append((page_number, prepared.copy()))
            prepared.close()
            manifest_blocks.append(
                {
                    "page": page_number,
                    "block_id": block_id,
                    "field": field,
                    "source_box": list(box),
                    "crop_method": "tesseract_label_anchor" if field in detected_boxes else "phase_alignment",
                    "image": str(block_path),
                    "image_sha256": sha256(block_path),
                }
            )
        image.close()

    preview_paths: dict[str, str] = {}
    for field, items in preview_items.items():
        preview_path = previews_dir / f"{field}.png"
        make_contact_sheet(field, items, preview_path)
        preview_paths[field] = str(preview_path)

    manifest = {
        "purpose": "Dummy-data 17-page isolated block OCR proof of concept",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source_pdf": render_manifest["source"],
        "source_pdf_sha256": render_manifest["source_sha256"],
        "page_count": render_manifest["rendered_pages"],
        "mapping_is_local_only": True,
        "reference_page": args.reference_page,
        "tsv_label_anchors_used": tsv_dir is not None,
        "alignments": alignments,
        "previews": preview_paths,
        "blocks": manifest_blocks,
    }
    manifest_path = output_dir / "block_map.local.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(manifest_path)
    print(f"blocks={len(manifest_blocks)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
