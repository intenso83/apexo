"""Extract Apexo tooth assets directly from the supplied odontogram chart.

The source chart is a regular 16-column grid. This script takes the first eight
columns (FDI 18 through 11 / 48 through 41), chroma-keys the mint background,
keeps the largest tooth component in each cell, and places the result on a
compact transparent square canvas without generative redrawing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter, deque
from pathlib import Path

from PIL import Image, ImageFilter


CANVAS_SIZE = 256
COLUMN_CENTERS = [64, 154, 244, 333, 423, 512, 602, 692]
ROW_BOUNDS = {
    "upper_facial": (52, 300),
    "upper_occlusal": (300, 395),
    "upper_palatal": (395, 516),
    "lower_lingual": (550, 655),
    "lower_occlusal": (655, 752),
    "lower_facial": (752, 997),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def largest_component(seed: list[bool], width: int, height: int) -> set[int]:
    visited = bytearray(width * height)
    largest: set[int] = set()
    for start, is_foreground in enumerate(seed):
        if not is_foreground or visited[start]:
            continue
        component: set[int] = set()
        queue: deque[int] = deque([start])
        visited[start] = 1
        while queue:
            index = queue.popleft()
            component.add(index)
            x = index % width
            y = index // width
            for nx, ny in (
                (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                (x - 1, y),                     (x + 1, y),
                (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
            ):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if seed[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        queue.append(neighbor)
        if len(component) > len(largest):
            largest = component
    return largest


def remove_background(crop: Image.Image, background: tuple[int, int, int]) -> Image.Image:
    rgb = crop.convert("RGB")
    pixels = list(rgb.get_flattened_data())
    raw_alpha: list[int] = []
    seed: list[bool] = []
    for red, green, blue in pixels:
        distance = math.sqrt(
            (red - background[0]) ** 2
            + (green - background[1]) ** 2
            + (blue - background[2]) ** 2
        )
        alpha = round(255 * max(0.0, min(1.0, (distance - 5.0) / 29.0)))
        raw_alpha.append(alpha)
        seed.append(alpha >= 48)

    width, height = rgb.size
    component = largest_component(seed, width, height)
    gate = Image.new("L", rgb.size, 0)
    gate_pixels = [255 if index in component else 0 for index in range(width * height)]
    gate.putdata(gate_pixels)
    gate = gate.filter(ImageFilter.MaxFilter(7))
    gate_values = list(gate.get_flattened_data())
    alpha_values = [a if g else 0 for a, g in zip(raw_alpha, gate_values)]

    cleaned_pixels: list[tuple[int, int, int, int]] = []
    for (red, green, blue), alpha in zip(pixels, alpha_values):
        if alpha == 0:
            cleaned_pixels.append((0, 0, 0, 0))
            continue
        if alpha < 255:
            fraction = alpha / 255.0
            red = round((red - background[0] * (1.0 - fraction)) / fraction)
            green = round((green - background[1] * (1.0 - fraction)) / fraction)
            blue = round((blue - background[2] * (1.0 - fraction)) / fraction)
        # Neutralize residual green spill from the chart's mint matte. This
        # changes only edge color, not the extracted silhouette or anatomy.
        neutral_edge = max(red, blue)
        if green > neutral_edge + 4:
            green = neutral_edge
        cleaned_pixels.append(
            (
                max(0, min(255, red)),
                max(0, min(255, green)),
                max(0, min(255, blue)),
                alpha,
            )
        )

    result = Image.new("RGBA", rgb.size)
    result.putdata(cleaned_pixels)
    bounds = result.getchannel("A").point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bounds is None:
        raise ValueError("No tooth component found in chart cell")
    left, top, right, bottom = bounds
    padding = 2
    return result.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(result.width, right + padding),
            min(result.height, bottom + padding),
        )
    )


def normalize(tooth: Image.Image, view: str) -> Image.Image:
    target_extent = 230 if view == "facial" else 190
    scale = min(target_extent / tooth.width, target_extent / tooth.height)
    new_size = (
        max(1, round(tooth.width * scale)),
        max(1, round(tooth.height * scale)),
    )
    resized = tooth.resize(new_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    position = ((CANVAS_SIZE - resized.width) // 2, (CANVAS_SIZE - resized.height) // 2)
    canvas.alpha_composite(resized, position)
    return canvas


def specs() -> list[tuple[int, int, str, str]]:
    result: list[tuple[int, int, str, str]] = []
    for tooth in range(11, 19):
        column = 18 - tooth
        middle = "incisal" if tooth <= 13 else "occlusal"
        result.extend(
            [
                (tooth, column, "facial", "upper_facial"),
                (tooth, column, middle, "upper_occlusal"),
                (tooth, column, "palatal", "upper_palatal"),
            ]
        )
    for tooth in range(41, 49):
        column = 48 - tooth
        middle = "incisal" if tooth <= 43 else "occlusal"
        result.extend(
            [
                (tooth, column, "facial", "lower_facial"),
                (tooth, column, middle, "lower_occlusal"),
                (tooth, column, "lingual", "lower_lingual"),
            ]
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    if source.size != (1488, 1043):
        raise SystemExit(f"Unexpected source size {source.size}; expected 1488x1043")
    background = Counter(source.get_flattened_data()).most_common(1)[0][0]
    args.destination.mkdir(parents=True, exist_ok=True)

    metadata: list[dict[str, object]] = []
    for tooth, column, view, row in specs():
        center = COLUMN_CENTERS[column]
        top, bottom = ROW_BOUNDS[row]
        chart_box = (max(0, center - 51), top, min(source.width, center + 51), bottom)
        chart_crop = source.crop(chart_box)
        extracted = remove_background(chart_crop, background)
        normalized = normalize(extracted, view)
        filename = f"tooth_{tooth}_{view}.png"
        destination = args.destination / filename
        normalized.save(destination, format="PNG", optimize=True)
        metadata.append(
            {
                "filename": filename,
                "source_box": chart_box,
                "extracted_size": extracted.size,
                "output_size": normalized.size,
                "sha256": sha256(destination),
            }
        )

    report = {
        "source": str(args.source.resolve()),
        "source_sha256": sha256(args.source),
        "source_size": source.size,
        "background_rgb": background,
        "output_canvas": [CANVAS_SIZE, CANVAS_SIZE],
        "asset_count": len(metadata),
        "assets": metadata,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
