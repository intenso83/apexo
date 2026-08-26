enum OdontogramJaw { upper, lower }

enum OdontogramToothType { incisor, canine, premolar, molar }

enum OdontogramView { facial, occlusalIncisal, oral }

enum DentalSurface {
  mesial,
  distal,
  facial,
  oral,
  occlusalIncisal,
  wholeTooth,
}

class OdontogramAsset {
  const OdontogramAsset({
    required this.fdi,
    required this.masterFdi,
    required this.jaw,
    required this.toothType,
    required this.view,
    required this.assetPath,
    required this.flipHorizontally,
  });

  final int fdi;
  final int masterFdi;
  final OdontogramJaw jaw;
  final OdontogramToothType toothType;
  final OdontogramView view;
  final String assetPath;
  final bool flipHorizontally;
}

/// Maps every permanent FDI tooth to the supplied, versioned master artwork.
///
/// The archive intentionally contains the right quadrants only. Left-side
/// teeth reuse the matching master and are mirrored at render time. Clinical
/// state is never painted into these files; it lives in separate event and
/// overlay layers.
class OdontogramAssets {
  static const version = 1;
  static const root = 'assets/odontogram/v1/png';

  static const upperFdi = <int>[
    18,
    17,
    16,
    15,
    14,
    13,
    12,
    11,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
  ];

  static const lowerFdi = <int>[
    48,
    47,
    46,
    45,
    44,
    43,
    42,
    41,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
  ];

  static const permanentFdi = <int>[...upperFdi, ...lowerFdi];

  static bool supports(int fdi) => permanentFdi.contains(fdi);

  static OdontogramAsset resolve(int fdi, OdontogramView view) {
    if (!supports(fdi)) {
      throw ArgumentError.value(fdi, 'fdi', 'Unsupported permanent FDI tooth');
    }
    final quadrant = fdi ~/ 10;
    final position = fdi % 10;
    final isLeft = quadrant == 2 || quadrant == 3;
    final masterQuadrant = quadrant == 1 || quadrant == 2 ? 1 : 4;
    final masterFdi = masterQuadrant * 10 + position;
    final jaw = masterQuadrant == 1 ? OdontogramJaw.upper : OdontogramJaw.lower;
    final toothType = _typeForPosition(position);
    final sourceView = switch (view) {
      OdontogramView.facial => 'facial',
      OdontogramView.occlusalIncisal =>
        toothType == OdontogramToothType.incisor ||
                toothType == OdontogramToothType.canine
            ? 'incisal'
            : 'occlusal',
      OdontogramView.oral => jaw == OdontogramJaw.upper ? 'palatal' : 'lingual',
    };
    return OdontogramAsset(
      fdi: fdi,
      masterFdi: masterFdi,
      jaw: jaw,
      toothType: toothType,
      view: view,
      assetPath: '$root/tooth_${masterFdi}_$sourceView.png',
      flipHorizontally: isLeft,
    );
  }

  static String surfaceLabel(DentalSurface surface, int fdi) {
    final isUpper = fdi ~/ 10 == 1 || fdi ~/ 10 == 2;
    final type = _typeForPosition(fdi % 10);
    return switch (surface) {
      DentalSurface.mesial => 'Mesial',
      DentalSurface.distal => 'Distal',
      DentalSurface.facial => 'Facial / buccal',
      DentalSurface.oral => isUpper ? 'Palatal' : 'Lingual',
      DentalSurface.occlusalIncisal => type == OdontogramToothType.incisor ||
              type == OdontogramToothType.canine
          ? 'Incisal'
          : 'Occlusal',
      DentalSurface.wholeTooth => 'Whole tooth',
    };
  }

  static OdontogramToothType _typeForPosition(int position) {
    return switch (position) {
      1 || 2 => OdontogramToothType.incisor,
      3 => OdontogramToothType.canine,
      4 || 5 => OdontogramToothType.premolar,
      6 || 7 || 8 => OdontogramToothType.molar,
      _ => throw ArgumentError.value(position, 'position'),
    };
  }
}
