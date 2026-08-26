import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:apexo/features/treatment_history/treatment_history_timeline.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
      'treatment history renders completed and planned entries read-only',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final entries = [
      TreatmentHistoryEntry.fromJson({
        'id': 'treatment000001',
        'patientID': 'patient00000001',
        'treatmentName': 'Composite restoration',
        'eventKind': 'clinical_event',
        'date': 29000000,
        'toothFdi': '11',
        'therapyGroup': 'Restorative',
        'catalogLinkMethod': 'stable_code',
        'notes': 'Imported note',
      }),
      TreatmentHistoryEntry.fromJson({
        'id': 'treatment000002',
        'patientID': 'patient00000001',
        'treatmentName': 'Review crown',
        'eventKind': 'treatment_plan_item',
        'catalogLinkMethod': 'legacy_custom',
      }),
    ];

    await pumpApexoApp(
      tester,
      ScaffoldPage(
        content: TreatmentHistoryTimeline(
          patientID: 'patient00000001',
          entries: entries,
        ),
      ),
    );

    expect(find.text('DentalWin treatment-history pilot'), findsOneWidget);
    expect(find.text('Composite restoration'), findsOneWidget);
    expect(find.text('Completed treatment'), findsOneWidget);
    expect(find.text('Tooth: 11'), findsOneWidget);
    expect(find.text('Restorative'), findsOneWidget);
    expect(find.text('Imported note'), findsOneWidget);
    expect(find.text('Review crown'), findsOneWidget);
    expect(find.text('Treatment-plan item'), findsOneWidget);
    expect(find.text('Legacy custom treatment'), findsOneWidget);
    expect(find.byType(TextBox), findsNothing);
  });
}
