"""Validate the odontogram PNG library and build its labeled contact sheet."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


EXPECTED_SIZE = (256, 256)


def tooth_specs() -> list[tuple[int, list[str]]]:
    specs: list[tuple[int, list[str]]] = []
    for tooth in range(11, 19):
        middle = "incisal" if tooth <= 13 else "occlusal"
        specs.append((tooth, ["facial", middle, "palatal"]))
    for tooth in range(41, 49):
        middle = "incisal" if tooth <= 43 else "occlusal"
        specs.append((tooth, ["facial", middle, "lingual"]))
    return specs


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def validate(png_dir: Path) -> dict[str, object]:
    expected = {
        f"tooth_{tooth}_{view}.png"
        for tooth, views in tooth_specs()
        for view in views
    }
    actual = {path.name for path in png_dir.glob("*.png")}
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    issues: list[str] = []
    hashes: dict[str, str] = {}
    margins: dict[str, int] = {}

    for filename in sorted(expected & actual):
        path = png_dir / filename
        file_hash = sha256(path)
        hashes[filename] = file_hash
        with Image.open(path) as opened:
            if opened.size != EXPECTED_SIZE:
                issues.append(f"{filename}: size {opened.size}, expected {EXPECTED_SIZE}")
            if opened.mode != "RGBA":
                issues.append(f"{filename}: mode {opened.mode}, expected RGBA")
                continue
            alpha = opened.getchannel("A")
            alpha_min, alpha_max = alpha.getextrema()
            if alpha_min != 0 or alpha_max < 250:
                issues.append(
                    f"{filename}: alpha extrema {(alpha_min, alpha_max)} are not transparent/opaque"
                )
            meaningful_alpha = alpha.point(lambda value: 255 if value >= 16 else 0)
            bounds = meaningful_alpha.getbbox()
            if bounds is None:
                issues.append(f"{filename}: fully transparent")
                continue
            left, top, right, bottom = bounds
            margin = min(left, top, opened.width - right, opened.height - bottom)
            margins[filename] = margin
            if margin < 8:
                issues.append(f"{filename}: content margin {margin}px is too small")

    duplicate_hashes: dict[str, list[str]] = {}
    by_hash: dict[str, list[str]] = {}
    for filename, file_hash in hashes.items():
        by_hash.setdefault(file_hash, []).append(filename)
    for file_hash, filenames in by_hash.items():
        if len(filenames) > 1:
            duplicate_hashes[file_hash] = sorted(filenames)

    return {
        "expected_count": len(expected),
        "actual_count": len(actual),
        "missing": missing,
        "extra": extra,
        "issues": issues,
        "duplicate_hashes": duplicate_hashes,
        "minimum_margin_px": min(margins.values()) if margins else None,
    }


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    name = "arialbd.ttf" if bold else "arial.ttf"
    candidate = Path("C:/Windows/Fonts") / name
    try:
        return ImageFont.truetype(str(candidate), size=size)
    except OSError:
        return ImageFont.load_default()


def draw_centered(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
) -> None:
    left, top, right, bottom = box
    text_box = draw.textbbox((0, 0), text, font=font)
    width = text_box[2] - text_box[0]
    height = text_box[3] - text_box[1]
    draw.text(
        (left + (right - left - width) / 2, top + (bottom - top - height) / 2),
        text,
        font=font,
        fill=fill,
    )


def build_contact_sheet(png_dir: Path, destination: Path) -> None:
    specs = tooth_specs()
    width = 1420
    header_height = 126
    row_height = 276
    label_width = 112
    col_width = (width - label_width) // 3
    height = header_height + row_height * len(specs)
    canvas = Image.new("RGBA", (width, height), (242, 240, 235, 255))
    draw = ImageDraw.Draw(canvas)
    title_font = load_font(34, bold=True)
    header_font = load_font(24, bold=True)
    row_font = load_font(28, bold=True)
    cell_font = load_font(18)
    dark = (52, 48, 43, 255)
    subtle = (103, 96, 86, 255)
    border = (207, 201, 191, 255)

    draw.text((32, 18), "Apexo Odontogram Master Assets v1", font=title_font, fill=dark)
    headers = ["Facial", "Occlusal / Incisal", "Palatal / Lingual"]
    for col, label in enumerate(headers):
        x0 = label_width + col * col_width
        draw_centered(
            draw,
            (x0, 68, x0 + col_width, header_height),
            label,
            header_font,
            subtle,
        )

    for row, (tooth, views) in enumerate(specs):
        y0 = header_height + row * row_height
        y1 = y0 + row_height
        row_fill = (250, 249, 246, 255) if row % 2 == 0 else (245, 243, 238, 255)
        draw.rectangle((0, y0, width, y1), fill=row_fill)
        draw.line((0, y0, width, y0), fill=border, width=2)
        draw_centered(draw, (0, y0, label_width, y1), str(tooth), row_font, dark)

        for col, view in enumerate(views):
            x0 = label_width + col * col_width
            x1 = x0 + col_width
            draw.line((x0, y0, x0, y1), fill=border, width=2)
            filename = f"tooth_{tooth}_{view}.png"
            with Image.open(png_dir / filename) as opened:
                image = opened.convert("RGBA")
            bounds = image.getchannel("A").getbbox()
            assert bounds is not None
            image = image.crop(bounds)
            image.thumbnail((244, 216), Image.Resampling.LANCZOS)
            px = x0 + (col_width - image.width) // 2
            py = y0 + 18 + (216 - image.height) // 2
            canvas.alpha_composite(image, (px, py))
            draw_centered(draw, (x0, y0 + 236, x1, y1 - 6), view, cell_font, subtle)

    draw.line((0, height - 1, width, height - 1), fill=border, width=2)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    png_dir = args.package / "png"
    result = validate(png_dir)
    if result["missing"] or result["extra"] or result["issues"] or result["duplicate_hashes"]:
        print(json.dumps(result, indent=2))
        raise SystemExit(1)
    build_contact_sheet(png_dir, args.package / "odontogram_contact_sheet.png")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
