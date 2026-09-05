import 'dart:ui' show Tristate;

import 'package:apexo/features/odontogram/dental_surface_selector.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('toggles a zone and reports the complete immutable selection',
      (tester) async {
    var selected = <DentalSurface>{DentalSurface.facial};
    Set<DentalSurface>? reported;
    final individualChanges = <(DentalSurface, bool)>[];

    await pumpApexoApp(
      tester,
      Center(
        child: StatefulBuilder(
          builder: (context, setState) => DentalSurfaceSelector(
            fdi: 11,
            selectedSurfaces: selected,
            onChanged: (next) {
              reported = next;
              setState(() => selected = next);
            },
            onSurfaceChanged: (surface, isSelected) {
              individualChanges.add((surface, isSelected));
            },
          ),
        ),
      ),
    );

    await _tapSurface(tester, fdi: 11, surface: DentalSurface.mesial);
    await tester.pump();

    expect(
      selected,
      {DentalSurface.facial, DentalSurface.mesial},
    );
    expect(individualChanges, [(DentalSurface.mesial, true)]);
    expect(
      () => reported!.add(DentalSurface.distal),
      throwsUnsupportedError,
    );

    await _tapSurface(tester, fdi: 11, surface: DentalSurface.mesial);
    await tester.pump();

    expect(selected, {DentalSurface.facial});
    expect(
      individualChanges,
      [
        (DentalSurface.mesial, true),
        (DentalSurface.mesial, false),
      ],
    );
  });

  testWidgets('adapts anatomical labels to jaw and tooth type', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpApexoApp(
        tester,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DentalSurfaceSelector(
              fdi: 11,
              selectedSurfaces: const {DentalSurface.occlusalIncisal},
              onChanged: (_) {},
            ),
            const SizedBox(width: 20),
            DentalSurfaceSelector(
              fdi: 46,
              selectedSurfaces: const {},
              onChanged: (_) {},
            ),
          ],
        ),
      );

      expect(
        tester
            .getSemantics(
              find.byKey(
                DentalSurfaceSelector.surfaceKey(11, DentalSurface.oral),
              ),
            )
            .label,
        'Palatal',
      );
      final incisal = tester.getSemantics(
        find.byKey(
          DentalSurfaceSelector.surfaceKey(
            11,
            DentalSurface.occlusalIncisal,
          ),
        ),
      );
      expect(incisal.label, 'Incisal');
      expect(incisal.flagsCollection.isSelected, Tristate.isTrue);
      expect(incisal.flagsCollection.isButton, isTrue);

      expect(
        tester
            .getSemantics(
              find.byKey(
                DentalSurfaceSelector.surfaceKey(46, DentalSurface.oral),
              ),
            )
            .label,
        'Lingual',
      );
      expect(
        tester
            .getSemantics(
              find.byKey(
                DentalSurfaceSelector.surfaceKey(
                  46,
                  DentalSurface.occlusalIncisal,
                ),
              ),
            )
            .label,
        'Occlusal',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('mirrors mesial and distal with the FDI quadrant',
      (tester) async {
    await pumpApexoApp(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DentalSurfaceSelector(
            fdi: 11,
            selectedSurfaces: const {},
            onChanged: (_) {},
          ),
          const SizedBox(width: 20),
          DentalSurfaceSelector(
            fdi: 21,
            selectedSurfaces: const {},
            onChanged: (_) {},
          ),
        ],
      ),
    );

    final selector11 = find.byKey(DentalSurfaceSelector.rootKey(11));
    expect(tester.widget<DentalSurfaceSelector>(selector11).fdi, 11);
    final centre11 = tester.getCenter(selector11);
    final mesial11 = tester.getCenter(
      find.byKey(
        DentalSurfaceSelector.surfaceKey(11, DentalSurface.mesial),
      ),
    );
    final distal11 = tester.getCenter(
      find.byKey(
        DentalSurfaceSelector.surfaceKey(11, DentalSurface.distal),
      ),
    );
    expect(mesial11.dx, greaterThan(centre11.dx));
    expect(distal11.dx, lessThan(centre11.dx));

    final centre21 = tester.getCenter(
      find.byKey(DentalSurfaceSelector.rootKey(21)),
    );
    final mesial21 = tester.getCenter(
      find.byKey(
        DentalSurfaceSelector.surfaceKey(21, DentalSurface.mesial),
      ),
    );
    final distal21 = tester.getCenter(
      find.byKey(
        DentalSurfaceSelector.surfaceKey(21, DentalSurface.distal),
      ),
    );
    expect(mesial21.dx, lessThan(centre21.dx));
    expect(distal21.dx, greaterThan(centre21.dx));
  });

  testWidgets('disabled selector exposes no tap action and does not change',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var changeCount = 0;

      await pumpApexoApp(
        tester,
        Center(
          child: DentalSurfaceSelector(
            fdi: 36,
            selectedSurfaces: const {DentalSurface.occlusalIncisal},
            enabled: false,
            onChanged: (_) => changeCount++,
          ),
        ),
      );

      final mesialFinder = find.byKey(
        DentalSurfaceSelector.surfaceKey(36, DentalSurface.mesial),
      );
      final mesialSemantics = tester.getSemantics(mesialFinder);
      expect(
        mesialSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      await _tapSurface(tester, fdi: 36, surface: DentalSurface.mesial);
      await tester.pump();
      expect(changeCount, 0);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _tapSurface(
  WidgetTester tester, {
  required int fdi,
  required DentalSurface surface,
}) async {
  final rect = tester.getRect(
    find.byKey(DentalSurfaceSelector.rootKey(fdi)),
  );
  final mesialOnLeft = fdi ~/ 10 == 2 || fdi ~/ 10 == 3;
  final normalized = switch (surface) {
    DentalSurface.mesial => Offset(mesialOnLeft ? 0.15 : 0.85, 0.50),
    DentalSurface.distal => Offset(mesialOnLeft ? 0.85 : 0.15, 0.50),
    DentalSurface.facial => const Offset(0.50, 0.85),
    DentalSurface.oral => const Offset(0.50, 0.15),
    DentalSurface.occlusalIncisal => const Offset(0.50, 0.50),
    DentalSurface.wholeTooth =>
      throw ArgumentError('Whole tooth is not a selectable zone'),
  };
  await tester.tapAt(
    Offset(
      rect.left + rect.width * normalized.dx,
      rect.top + rect.height * normalized.dy,
    ),
  );
}
