APEXO ODONTOGRAM MASTER ASSETS V1
=================================

This package contains the complete adult permanent-tooth master image library for
the right-side FDI quadrants used by the Apexo Flutter odontogram.

CONTENTS
--------
png/                              48 transparent PNG tooth assets
manifest.csv                      Machine-readable asset metadata
odontogram_contact_sheet.png      Visual index rendered from the saved assets
generation_report.txt             Source, processing, and integrity report

SOURCE AND METHOD
-----------------
All 48 tooth assets were extracted directly from the supplied odontogram chart:
Screenshot 2026-08-26 231936.png (source size 1488 x 1043 pixels).

The first eight chart columns provide FDI 18 through 11 in the upper jaw and FDI
48 through 41 in the lower jaw. The tooth pixels and anatomy come from that chart.
No tooth was generatively redrawn or anatomically invented.

The chart's mint background, labels, and divider were excluded. Residual mint edge
spill was neutralized without changing tooth silhouettes. Each extracted tooth was
then centered on a compact 256 x 256 transparent RGBA canvas.

CONSERVATIVE RETOUCH
-------------------
A restrained, non-generative finishing pass was applied to every asset. It uses
gentle compression-noise reduction, neutral color balancing, mild contrast and
clarity enhancement, and sub-pixel alpha-edge smoothing. Tooth anatomy, view,
proportions, and meaningful silhouettes remain unchanged.

NAMING CONVENTION
-----------------
tooth_<FDI tooth number>_<view>.png

Examples:
tooth_11_facial.png
tooth_14_occlusal.png
tooth_43_lingual.png

Each tooth has exactly three views:
- Upper incisors/canine: facial, incisal, palatal
- Upper premolars/molars: facial, occlusal, palatal
- Lower incisors/canine: facial, incisal, lingual
- Lower premolars/molars: facial, occlusal, lingual

VIEW-ROW MAPPING
----------------
- Upper facial: chart's upper full-tooth row
- Upper incisal/occlusal: chart's upper middle row
- Upper palatal: chart's upper crown row
- Lower lingual: chart's first row below the divider
- Lower incisal/occlusal: chart's lower middle row
- Lower facial: chart's lower full-tooth row

MIRRORING FOR LEFT-SIDE FDI TEETH
---------------------------------
The supplied assets are anatomically right-side masters. Mirror them horizontally
at runtime to display the corresponding left-side teeth:

11-18 -> 21-28
41-48 -> 31-38

The mirrored_left_fdi_number column in manifest.csv records the exact mapping.

TECHNICAL NOTES
---------------
- All PNGs are square 256 x 256 RGBA images with genuine transparency.
- Facial views use the chart's full-tooth illustrations, including roots.
- Other views use the chart's crown-view illustrations.
- Assets are centered with transparent padding suitable for Flutter overlays.
- The compact output size reflects the actual detail available in the screenshot.
- The retouch is deterministic and introduces no generated dental structures.

TREATMENT AND CONDITION OVERLAYS
--------------------------------
These files are neutral base anatomy only. Caries, restorations, crowns, bridges,
implants, endodontic marks, missing-tooth symbols, periodontal indicators, and
other clinical states should be implemented as separate Flutter overlay layers.
Do not bake treatment-state markings into these master PNGs.
