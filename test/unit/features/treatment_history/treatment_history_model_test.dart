import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
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
      'sourceTable': 'WorksPelati',
      'sourceRecordKey': '401',
      'chartRole': 'performed_work',
      'surfaces': ['mesial', 'occlusalIncisal', 'facial'],
      'cervicalSurfaces': ['facial'],
      'drawingBehavior': 'filling',
      'materialColorArgb': 0xFF0066CC,
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
    expect(roundTrip.sourceTable, 'WorksPelati');
    expect(roundTrip.sourceRecordKey, '401');
    expect(roundTrip.chartRole, 'performed_work');
    expect(roundTrip.surfaces, ['mesial', 'occlusalIncisal', 'facial']);
    expect(roundTrip.cervicalSurfaces, ['facial']);
    expect(roundTrip.drawingBehavior, OdontogramDrawingBehavior.filling);
    expect(roundTrip.materialColorArgb, 0xFF0066CC);
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
