import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visual treatment pilot for representative permanent teeth',
      (tester) async {
    tester.view.physicalSize = const Size(900, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: Key('odontogram-visual-pilot'),
          child: ColoredBox(
            color: Color(0xFFF4FAFA),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PilotCell(
                    label: '11 · Crown',
                    fdi: 11,
                    marker: OdontogramOverlayMarker(
                      kind: OdontogramOverlayKind.crown,
                      status: OdontogramEventStatus.completed,
                      procedureName: 'Zirconia ceramic crown',
                      surfaces: {DentalSurface.wholeTooth},
                    ),
                  ),
                  _PilotCell(
                    label: '16 · Filling',
                    fdi: 16,
                    marker: OdontogramOverlayMarker(
                      kind: OdontogramOverlayKind.filling,
                      status: OdontogramEventStatus.completed,
                      procedureName: 'Composite filling MO',
                      surfaces: {
                        DentalSurface.mesial,
                        DentalSurface.occlusalIncisal,
                      },
                    ),
                  ),
                  _PilotCell(
                    label: '16 · Endodontics',
                    fdi: 16,
                    marker: OdontogramOverlayMarker(
                      kind: OdontogramOverlayKind.rootCanal,
                      status: OdontogramEventStatus.completed,
                      surfaces: {DentalSurface.wholeTooth},
                    ),
                  ),
                  _PilotCell(
                    label: '46 · Implant',
                    fdi: 46,
                    fadeTooth: true,
                    marker: OdontogramOverlayMarker(
                      kind: OdontogramOverlayKind.implant,
                      status: OdontogramEventStatus.completed,
                      surfaces: {DentalSurface.wholeTooth},
                    ),
                  ),
                  _PilotCell(
                    label: '46 · Extraction',
                    fdi: 46,
                    fadeTooth: true,
                    marker: OdontogramOverlayMarker(
                      kind: OdontogramOverlayKind.extraction,
                      status: OdontogramEventStatus.completed,
                      surfaces: {DentalSurface.wholeTooth},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(
      find.byKey(const Key('odontogram-visual-pilot')),
    );
    await tester.runAsync(() async {
      for (final fdi in const [11, 16, 46]) {
        for (final view in OdontogramView.values) {
          await precacheImage(
            AssetImage(OdontogramAssets.resolve(fdi, view).assetPath),
            context,
          );
        }
      }
    });
    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('odontogram-visual-pilot')),
      matchesGoldenFile('goldens/odontogram_visual_pilot.png'),
    );
  });
}

class _PilotCell extends StatelessWidget {
  const _PilotCell({
    required this.label,
    required this.fdi,
    required this.marker,
    this.fadeTooth = false,
  });

  final String label;
  final int fdi;
  final OdontogramOverlayMarker marker;
  final bool fadeTooth;

  @override
  Widget build(BuildContext context) => Container(
        width: 158,
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E7E7)),
        ),
        child: Column(
          children: [
            Semantics(
              label: label,
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: odontogramTreatmentMaterialColor(marker.kind),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final view in OdontogramView.values)
              _PilotToothView(
                fdi: fdi,
                view: view,
                marker: marker,
                fadeTooth: fadeTooth,
              ),
          ],
        ),
      );
}

class _PilotToothView extends StatelessWidget {
  const _PilotToothView({
    required this.fdi,
    required this.view,
    required this.marker,
    required this.fadeTooth,
  });

  final int fdi;
  final OdontogramView view;
  final OdontogramOverlayMarker marker;
  final bool fadeTooth;

  @override
  Widget build(BuildContext context) {
    final asset = OdontogramAssets.resolve(fdi, view);
    Widget tooth = Image.asset(
      asset.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (asset.flipHorizontally) {
      tooth = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: tooth,
      );
    }
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: fadeTooth ? 0.20 : 1, child: tooth),
          OdontogramTreatmentOverlayLayer(marker: marker, asset: asset),
        ],
      ),
    );
  }
}
