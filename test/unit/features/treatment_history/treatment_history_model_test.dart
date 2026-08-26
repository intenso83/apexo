import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('treatment history round-trip preserves imported clinical fields', () {
    final entry = TreatmentHistoryEntry.fromJson({
      'id': 'historyentry01',
      'patientID': 'patient00000001',
      'title': 'Composite restoration',
      'treatmentName': 'Composite restoration',
      'eventKind': 'clinical_event',
      'date': 29000000,
      'toothRaw': '11',
      'toothFdi': '11',
      'notes': 'Imported note',
      'chargeRaw': '50',
      'catalogLinkMethod': 'stable_code',
      'therapyGroup': 'Restorative',
      'migration': {'pilot': true},
    });

    expect(entry.patientID, 'patient00000001');
    expect(entry.isCompletedTreatment, isTrue);
    expect(entry.displayedTooth, '11');
    expect(entry.hasMappedCatalog, isTrue);
    expect(entry.date, isNotNull);

    final roundTrip = TreatmentHistoryEntry.fromJson(entry.toJson());
    expect(roundTrip.treatmentName, 'Composite restoration');
    expect(roundTrip.therapyGroup, 'Restorative');
    expect(roundTrip.notes, 'Imported note');
    expect(roundTrip.migration['pilot'], isTrue);
  });

  test('treatment plan and legacy custom values remain distinguishable', () {
    final entry = TreatmentHistoryEntry.fromJson({
      'eventKind': 'treatment_plan_item',
      'treatmentName': 'Legacy proposal',
      'toothRaw': 'unclear',
      'catalogLinkMethod': 'legacy_custom',
    });

    expect(entry.isTreatmentPlanItem, isTrue);
    expect(entry.hasMappedCatalog, isFalse);
    expect(entry.displayedTooth, 'unclear');
    expect(entry.date, isNull);
  });
}
