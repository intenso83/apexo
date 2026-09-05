from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageOps


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render a dummy PDF batch for OCR QA.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--expected-pages", required=True, type=int)
    parser.add_argument("--scale", default=2.4, type=float)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    args = parse_args()
    source = args.input.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    pages_dir = output_dir / "pages"
    pages_dir.mkdir(parents=True, exist_ok=True)

    document = pdfium.PdfDocument(source)
    if len(document) != args.expected_pages:
        raise ValueError(f"Expected {args.expected_pages} pages; got {len(document)}")

    rendered: list[dict[str, object]] = []
    thumbnails: list[Image.Image] = []
    for index in range(len(document)):
        page_number = index + 1
        page = document[index]
        bitmap = page.render(scale=args.scale)
        image = bitmap.to_pil().convert("RGB")
        page_path = pages_dir / f"page-{page_number:02d}.png"
        image.save(page_path, format="PNG", optimize=True)
        thumbnail = ImageOps.contain(image, (330, 470), Image.Resampling.LANCZOS)
        thumbnails.append(thumbnail.copy())
        rendered.append(
            {
                "page": page_number,
                "image": str(page_path),
                "width": image.width,
                "height": image.height,
                "image_sha256": sha256(page_path),
            }
        )
        thumbnail.close()
        image.close()
        bitmap.close()
        page.close()
    document.close()

    columns = 4
    cell_width, cell_height = 360, 520
    rows = (len(thumbnails) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_width, rows * cell_height), "white")
    draw = ImageDraw.Draw(sheet)
    for index, thumbnail in enumerate(thumbnails):
        x = (index % columns) * cell_width + (cell_width - thumbnail.width) // 2
        y = (index // columns) * cell_height + 35
        sheet.paste(thumbnail, (x, y))
        draw.text((index % columns * cell_width + 12, index // columns * cell_height + 10), f"Page {index + 1}", fill="black")
        thumbnail.close()
    sheet_path = output_dir / "contact_sheet.png"
    sheet.save(sheet_path, format="PNG", optimize=True)
    sheet.close()

    manifest = {
        "purpose": "Dummy PDF rendering for block OCR proof of concept",
        "source": str(source),
        "source_sha256": sha256(source),
        "expected_pages": args.expected_pages,
        "rendered_pages": len(rendered),
        "scale": args.scale,
        "pages": rendered,
    }
    manifest_path = output_dir / "render_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(manifest_path)
    print(sheet_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
