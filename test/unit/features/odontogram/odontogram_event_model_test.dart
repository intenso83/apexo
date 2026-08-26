import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event round-trip keeps the clinical snapshot stable', () {
    final event = OdontogramEvent.fromJson({
      'id': 'event1234567890',
      'patientID': 'patient1234567',
      'toothFdi': 16,
      'surfaces': ['mesial', 'occlusalIncisal'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Composite filling',
      'therapyGroupID': 'group1234567890',
      'therapyGroupNameSnapshot': 'Restorative',
      'priceSnapshot': 80,
      'eventKind': 'treatment',
      'status': 'completed',
      'recordedAt': 30000000,
    });
    expect(event.validationErrors(), isEmpty);
    expect(OdontogramEvent.fromJson(event.toJson()).toJson(), event.toJson());
  });

  test('legacy event may honestly leave the surface unspecified', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'toothFdi': 36,
      'procedureNameSnapshot': 'Legacy treatment',
      'eventKind': 'condition',
      'migration': {'source': 'DentalWin'},
    });
    expect(event.isLegacyWholeTooth, isTrue);
    expect(event.validationErrors(), isEmpty);
  });

  test('whole tooth cannot be combined with individual surfaces', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'toothFdi': 11,
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Crown',
      'surfaces': ['wholeTooth', 'facial'],
    });
    expect(event.validationErrors(), contains('surfaces'));
  });
}
