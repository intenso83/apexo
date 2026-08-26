import 'dart:io';

import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 32 permanent FDI teeth resolve in all three views', () {
    for (final fdi in OdontogramAssets.permanentFdi) {
      for (final view in OdontogramView.values) {
        final asset = OdontogramAssets.resolve(fdi, view);
        expect(File(asset.assetPath).existsSync(), isTrue,
            reason: 'Missing ${asset.assetPath}');
      }
    }
  });

  test('left quadrants reuse and mirror the matching right master', () {
    final upperLeft = OdontogramAssets.resolve(26, OdontogramView.oral);
    expect(upperLeft.masterFdi, 16);
    expect(upperLeft.flipHorizontally, isTrue);
    expect(upperLeft.assetPath, endsWith('tooth_16_palatal.png'));

    final lowerLeft =
        OdontogramAssets.resolve(34, OdontogramView.occlusalIncisal);
    expect(lowerLeft.masterFdi, 44);
    expect(lowerLeft.flipHorizontally, isTrue);
    expect(lowerLeft.assetPath, endsWith('tooth_44_occlusal.png'));
  });

  test('right-side masters are never mirrored', () {
    for (final fdi in [11, 18, 41, 48]) {
      expect(
        OdontogramAssets.resolve(fdi, OdontogramView.facial).flipHorizontally,
        isFalse,
      );
    }
  });

  test('archive manifest describes exactly the imported master files', () {
    final lines = File('assets/odontogram/v1/manifest.csv').readAsLinesSync();
    expect(lines.first,
        'filename,fdi_tooth_number,jaw,tooth_type,view,crown_only,mirrored_left_fdi_number');
    final manifestNames =
        lines.skip(1).map((line) => line.split(',').first).toSet();
    final pngNames = Directory('assets/odontogram/v1/png')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(manifestNames.length, 48);
    expect(pngNames, manifestNames);
  });

  test('all supplied PNG masters are transparent 256 by 256 images', () {
    for (final file
        in Directory('assets/odontogram/v1/png').listSync().whereType<File>()) {
      final bytes = file.readAsBytesSync();
      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      int readUint32(int offset) =>
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      expect(readUint32(16), 256, reason: file.path);
      expect(readUint32(20), 256, reason: file.path);
      expect(bytes[25], 6, reason: '${file.path} must be RGBA');
    }
  });
}
