"""Apply a conservative, anatomy-preserving retouch to odontogram PNG assets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


EXPECTED_SIZE = (256, 256)


def meaningful_bounds(alpha: Image.Image) -> tuple[int, int, int, int] | None:
    return alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()


def retouch(source: Image.Image) -> Image.Image:
    original = source.convert("RGBA")
    if original.size != EXPECTED_SIZE:
        raise ValueError(f"Expected {EXPECTED_SIZE}, found {original.size}")

    alpha = original.getchannel("A")

    # Work against a clean neutral matte so color filters cannot pull black or
    # colored pixels from the transparent canvas into antialiased tooth edges.
    neutral = Image.new("RGB", original.size, (248, 248, 246))
    neutral.paste(original.convert("RGB"), mask=alpha)

    # Remove a small amount of screenshot/compression noise while retaining the
    # chart's fissures, ridges, crown outlines, and root morphology.
    median = neutral.filter(ImageFilter.MedianFilter(3))
    cleaned = Image.blend(neutral, median, 0.18)

    # Subtle clinical-neutral color and tonal correction; deliberately restrained.
    cleaned = ImageEnhance.Color(cleaned).enhance(0.94)
    cleaned = ImageEnhance.Contrast(cleaned).enhance(1.045)
    cleaned = ImageEnhance.Brightness(cleaned).enhance(1.012)

    detail = cleaned.filter(ImageFilter.UnsharpMask(radius=0.8, percent=52, threshold=4))
    cleaned = Image.blend(cleaned, detail, 0.72)

    # Smooth only the antialiased edge transition. The meaningful silhouette is
    # checked after processing and may not move by more than one pixel.
    softened_alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.38))
    final_alpha = Image.blend(alpha, softened_alpha, 0.42).point(
        lambda value: 0 if value < 5 else (255 if value > 250 else value)
    )

    result = cleaned.convert("RGBA")
    result.putalpha(final_alpha)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    source_files = sorted(args.source.glob("*.png"))
    if len(source_files) != 48:
        raise SystemExit(f"Expected 48 source PNGs, found {len(source_files)}")
    if args.destination.exists() and any(args.destination.iterdir()):
        raise SystemExit(f"Destination must be empty: {args.destination}")
    args.destination.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, object]] = []
    for path in source_files:
        with Image.open(path) as opened:
            original = opened.convert("RGBA")
        before = meaningful_bounds(original.getchannel("A"))
        result = retouch(original)
        after = meaningful_bounds(result.getchannel("A"))
        if before is None or after is None:
            raise SystemExit(f"Empty alpha silhouette: {path.name}")
        max_shift = max(abs(a - b) for a, b in zip(before, after))
        if max_shift > 1:
            raise SystemExit(f"Silhouette shifted by {max_shift}px: {path.name}")
        destination = args.destination / path.name
        result.save(destination, format="PNG", optimize=True)
        records.append(
            {
                "filename": path.name,
                "silhouette_before": before,
                "silhouette_after": after,
                "maximum_edge_shift_px": max_shift,
            }
        )

    print(
        json.dumps(
            {
                "asset_count": len(records),
                "maximum_edge_shift_px": max(
                    record["maximum_edge_shift_px"] for record in records
                ),
                "records": records,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
