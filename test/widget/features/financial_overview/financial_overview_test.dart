import 'package:apexo/features/financial_overview/financial_overview.dart';
import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('financial overview keeps current and legacy money separate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final entries = [
      TreatmentHistoryEntry.fromJson({
        'patientID': 'patient00000001',
        'treatmentName': 'Historical treatment',
        'eventKind': 'clinical_event',
        'date': 29000000,
        'chargeRaw': '100',
        'creditRaw': '20',
        'totalRaw': '95',
      }),
    ];

    await pumpApexoApp(
      tester,
      ScaffoldPage(
        content: PatientFinancialOverview(
          patientID: 'patient00000001',
          historyEntries: entries,
          appointmentEntries: const [],
          currencySymbol: 'EUR',
        ),
      ),
    );

    expect(find.text('Financial overview pilot'), findsOneWidget);
    expect(find.text('Current Apexo financials'), findsOneWidget);
    expect(find.text('Legacy DentalWin financial snapshot'), findsOneWidget);
    // Each imported value appears in both the legacy summary and its yearly
    // breakdown. Current Apexo values stay separate and remain zero here.
    expect(find.text('100.00 EUR'), findsNWidgets(2));
    expect(find.text('20.00 EUR'), findsNWidgets(2));
    expect(find.text('95.00 EUR'), findsNWidgets(2));
    expect(find.text('0.00 EUR'), findsNWidgets(3));
    expect(
        find.text('Legacy values are not an active balance'), findsOneWidget);
    expect(find.byType(TextBox), findsNothing);
  });
}
