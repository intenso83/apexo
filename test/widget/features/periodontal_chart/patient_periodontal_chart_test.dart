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
  });
}
