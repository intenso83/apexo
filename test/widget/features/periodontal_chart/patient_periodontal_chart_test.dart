import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/periodontal_chart/patient_periodontal_chart.dart';
import 'package:apexo/features/periodontal_chart/periodontal_chart_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('creates and saves a six-site periodontal examination',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final patient = Patient.fromJson({
      'id': 'patient1234567',
      'title': 'Demo Patient',
    });
    PeriodontalChart? saved;
    await pumpApexoApp(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 1200,
          child: PatientPeriodontalChart(
            patient: patient,
            charts: const [],
            onChartSaved: (chart) => saved = chart,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('new-periodontal-exam')));
    await tester.pumpAndSettle();

    expect(find.text('18'), findsWidgets);
    expect(find.text('48'), findsWidgets);
    expect(find.text('PD'), findsWidgets);
    expect(find.text('CAL'), findsWidgets);

    final tooth18Sites = [
      PeriodontalSite.mesioBuccal,
      PeriodontalSite.buccal,
      PeriodontalSite.distoBuccal,
      PeriodontalSite.mesioLingual,
      PeriodontalSite.lingual,
      PeriodontalSite.distoLingual,
    ];
    const pocketValues = [5, 8, 2, 9, 5, 1];
    for (var index = 0; index < tooth18Sites.length; index++) {
      final field = find.byKey(ValueKey(
        'periodontal-pd-18-${tooth18Sites[index].name}',
      ));
      await tester.enterText(field, '${pocketValues[index]}');
      if (pocketValues[index] == 1) {
        await tester.pump(const Duration(milliseconds: 600));
      } else {
        await tester.pump();
      }
      final nextTooth = index == tooth18Sites.length - 1 ? 17 : 18;
      final nextSite = index == tooth18Sites.length - 1
          ? PeriodontalSite.mesioBuccal
          : tooth18Sites[index + 1];
      final nextField = find.byKey(ValueKey(
        'periodontal-pd-$nextTooth-${nextSite.name}',
      ));
      final nextTextBox = tester.widget<TextBox>(find.descendant(
        of: nextField,
        matching: find.byType(TextBox),
      ));
      expect(nextTextBox.focusNode!.hasFocus, isTrue);
    }

    // A leading 1 waits briefly, allowing a two-digit depth from 10 to 15.
    final tooth17Mb = find.byKey(
      const ValueKey('periodontal-pd-17-mesioBuccal'),
    );
    await tester.enterText(tooth17Mb, '1');
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<TextBox>(find.descendant(
            of: tooth17Mb,
            matching: find.byType(TextBox),
          ))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(tooth17Mb, '12');
    await tester.pump();
    expect(
      tester
          .widget<TextBox>(find.descendant(
            of: find.byKey(
              const ValueKey('periodontal-pd-17-buccal'),
            ),
            matching: find.byType(TextBox),
          ))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-periodontal-exam')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('save-periodontal-exam')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(saved, isNotNull);
    expect(saved!.patientID, patient.id);
    expect(saved!.teeth.length, 32);
    expect(saved!.tooth(18).sites.length, 6);
    expect(
      tooth18Sites
          .map((site) => saved!.tooth(18).measurement(site).probingDepth)
          .toList(),
      pocketValues,
    );
    expect(
      saved!.tooth(17).measurement(PeriodontalSite.mesioBuccal).probingDepth,
      12,
    );
  });
}
