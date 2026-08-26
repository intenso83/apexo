APEXO ODONTOGRAM MASTER ASSETS V1
=================================

This package contains the complete adult permanent-tooth master image library for
the right-side FDI quadrants used by the Apexo Flutter odontogram.

CONTENTS
--------
png/                              48 transparent PNG tooth assets
manifest.csv                      Machine-readable asset metadata
odontogram_contact_sheet.png      Visual index rendered from the saved assets
generation_report.txt             Completion, retry, and integrity report

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

MIRRORING FOR LEFT-SIDE FDI TEETH
---------------------------------
The supplied assets are anatomically right-side masters. Mirror them horizontally
at runtime to display the corresponding left-side teeth:

11-18 -> 21-28
41-48 -> 31-38

The mirrored_left_fdi_number column in manifest.csv records the exact mapping.

VIEW GEOMETRY
-------------
- Facial views contain the full tooth, including the complete root or roots.
- Incisal, occlusal, palatal, and lingual views are crown-only.
- All PNGs are square 1254 x 1254 RGBA canvases with transparent backgrounds.
- Each tooth is centered with transparent padding suitable for Flutter overlays.

TREATMENT AND CONDITION OVERLAYS
--------------------------------
These files are neutral base anatomy only. Caries, restorations, crowns, bridges,
implants, endodontic marks, missing-tooth symbols, periodontal indicators, and
other clinical states should be implemented as separate Flutter overlay layers.
Do not bake treatment-state markings into these master PNGs.

APPROVED REFERENCE MASTERS
--------------------------
The six approved reference files for teeth 11 and 16 are included unchanged,
byte-for-byte. All other files were created to match their clinical illustration
system and package geometry.
