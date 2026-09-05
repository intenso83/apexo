from __future__ import annotations

import argparse
import hashlib
import json
import secrets
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


# Coordinates are for the 1700 x 2339 dummy form used by the proof of concept.
# They deliberately isolate values that would normally identify one another.
BLOCKS: tuple[tuple[str, tuple[int, int, int, int]], ...] = (
    ("full_name", (75, 365, 1325, 420)),
    ("address", (75, 410, 740, 462)),
    ("mobile", (505, 445, 1100, 500)),
    ("email", (850, 405, 1665, 463)),
    ("registration_date", (95, 2035, 705, 2110)),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare privacy-compartmentalized OCR blocks from the dummy form."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def prepare_block(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = image.crop(box).convert("RGB")
    crop = ImageOps.expand(crop, border=24, fill="white")
    crop = ImageEnhance.Contrast(crop).enhance(1.12)
    crop = ImageEnhance.Sharpness(crop).enhance(1.35)
    return crop.resize(
        (crop.width * 2, crop.height * 2),
        Image.Resampling.LANCZOS,
    )


def main() -> int:
    args = parse_args()
    source = args.input.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    blocks_dir = output_dir / "blocks"
    blocks_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(source) as opened:
        image = opened.convert("RGB")

    if image.size != (1700, 2339):
        raise ValueError(
            f"This proof of concept expects the 1700x2339 dummy form; got {image.size}."
        )

    preview = image.copy()
    draw = ImageDraw.Draw(preview)
    manifest_blocks: list[dict[str, object]] = []

    for ordinal, (field_name, box) in enumerate(BLOCKS, start=1):
        block_id = secrets.token_hex(12).upper()
        block_path = blocks_dir / f"{block_id}.png"
        prepared = prepare_block(image, box)
        prepared.save(block_path, format="PNG", optimize=True)
        prepared.close()

        draw.rectangle(box, outline=(220, 20, 60), width=4)
        draw.rectangle((box[0], box[1], box[0] + 55, box[1] + 28), fill=(220, 20, 60))
        draw.text((box[0] + 8, box[1] + 5), str(ordinal), fill="white")
        manifest_blocks.append(
            {
                "ordinal": ordinal,
                "block_id": block_id,
                "field": field_name,
                "source_box": list(box),
                "image": str(block_path),
                "image_sha256": sha256(block_path),
            }
        )

    preview_path = output_dir / "local_block_map.png"
    preview.save(preview_path, format="PNG", optimize=True)
    preview.close()
    image.close()

    manifest = {
        "purpose": "Dummy-data block OCR proof of concept",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "source_sha256": sha256(source),
        "mapping_is_local_only": True,
        "blocks": manifest_blocks,
    }
    manifest_path = output_dir / "block_map.local.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(manifest_path)
    print(preview_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
