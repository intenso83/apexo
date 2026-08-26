import 'package:apexo/features/financial_overview/financial_overview.dart';
import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy money parser accepts simple DentalWin numeric formats', () {
    expect(LegacyFinancialSnapshot.parseLegacyMoney('50'), 50);
    expect(LegacyFinancialSnapshot.parseLegacyMoney('12,50'), 12.5);
    expect(LegacyFinancialSnapshot.parseLegacyMoney('-4.25'), -4.25);
    expect(LegacyFinancialSnapshot.parseLegacyMoney('(7,00)'), -7);
    expect(LegacyFinancialSnapshot.parseLegacyMoney(''), isNull);
    expect(LegacyFinancialSnapshot.parseLegacyMoney('EUR 50'), isNull);
  });

  test('legacy snapshot separates completed and planned values', () {
    final snapshot = LegacyFinancialSnapshot.fromEntries([
      TreatmentHistoryEntry.fromJson({
        'eventKind': 'clinical_event',
        'chargeRaw': '100',
        'creditRaw': '25',
        'totalRaw': '75',
      }),
      TreatmentHistoryEntry.fromJson({
        'eventKind': 'clinical_event',
        'chargeRaw': '50',
        'creditRaw': '0',
        'totalRaw': '40',
      }),
      TreatmentHistoryEntry.fromJson({
        'eventKind': 'treatment_plan_item',
        'chargeRaw': '80',
        'totalRaw': '70',
      }),
    ]);

    expect(snapshot.completedRows, 2);
    expect(snapshot.plannedRows, 1);
    expect(snapshot.recordedCharges, 150);
    expect(snapshot.recordedCredits, 25);
    expect(snapshot.recordedSourceTotal, 115);
    expect(snapshot.plannedSourceValue, 70);
    expect(snapshot.sourceTotalsReconcile, isFalse);
    expect(snapshot.discrepancy, -10);
  });
}
