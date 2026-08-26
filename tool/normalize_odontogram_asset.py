"""Normalize a generated odontogram PNG without altering locked master assets."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CANVAS_SIZE = 1254
MAX_CONTENT_SIZE = 1080


def normalize(source: Path, destination: Path) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")

    alpha = image.getchannel("A")
    if alpha.getextrema() != (0, 255):
        raise ValueError(f"{source} does not contain genuine transparent and opaque pixels")

    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"{source} is fully transparent")

    content = image.crop(bounds)
    width, height = content.size
    scale = min(1.0, MAX_CONTENT_SIZE / max(width, height))
    if scale < 1.0:
        content = content.resize(
            (max(1, round(width * scale)), max(1, round(height * scale))),
            Image.Resampling.LANCZOS,
        )

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - content.width) // 2
    y = (CANVAS_SIZE - content.height) // 2
    canvas.alpha_composite(content, (x, y))

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    normalize(args.source, args.destination)


if __name__ == "__main__":
    main()
