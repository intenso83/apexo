import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event round-trip keeps the clinical snapshot stable', () {
    final event = OdontogramEvent.fromJson({
      'id': 'event1234567890',
      'patientID': 'patient1234567',
      'toothFdi': 16,
      'surfaces': ['mesial', 'occlusalIncisal', 'facial'],
      'cervicalSurfaces': ['facial'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Composite filling',
      'therapyGroupID': 'group1234567890',
      'therapyGroupNameSnapshot': 'Restorative',
      'overlayKind': 'filling',
      'drawingBehavior': 'filling',
      'materialColorArgb': 0xFF336699,
      'priceSnapshot': 80,
      'eventKind': 'treatment',
      'status': 'completed',
      'recordedAt': 30000000,
      'treatmentHistoryID': 'history12345678',
      'laboratoryID': 'laboratory-1',
      'laboratoryNameSnapshot': 'Praxis Lab',
      'laboratoryCost': 82.5,
    });
    expect(event.validationErrors(), isEmpty);
    expect(event.laboratoryID, 'laboratory-1');
    expect(event.laboratoryNameSnapshot, 'Praxis Lab');
    expect(event.laboratoryCost, 82.5);
    expect(event.drawingBehavior, OdontogramDrawingBehavior.filling);
    expect(event.materialColorArgb, 0xFF336699);
    expect(event.treatmentHistoryID, 'history12345678');
    expect(OdontogramEvent.fromJson(event.toJson()).toJson(), event.toJson());
    expect(event.effectiveOverlayKind, OdontogramOverlayKind.filling);
  });

  test('primary FDI teeth remain explicitly valid migration locations', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'toothFdi': 55,
      'surfaces': ['occlusalIncisal'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Primary molar filling',
    });
    expect(isPrimaryFdi(55), isTrue);
    expect(isPermanentFdi(55), isFalse);
    expect(event.validationErrors(), isEmpty);
  });

  test('cervical location must be facial or oral and selected', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'toothFdi': 16,
      'surfaces': ['mesial'],
      'cervicalSurfaces': ['facial'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Invalid cervical snapshot',
    });
    expect(event.validationErrors(), contains('cervicalSurfaces'));
  });

  test('legacy event infers its overlay without rewriting the source record',
      () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'toothFdi': 16,
      'surfaces': ['wholeTooth'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Ενδοδοντική θεραπεία γομφίου',
      'therapyGroupNameSnapshot': 'Ενδοδοντία',
    });
    expect(event.overlayKind, isNull);
    expect(event.effectiveOverlayKind, OdontogramOverlayKind.rootCanal);
    expect(event.toJson(), isNot(contains('overlayKind')));
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

  test('a new tooth treatment may intentionally omit surface mapping', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'tooth',
      'toothFdi': 16,
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Filling',
    });
    expect(event.validationErrors(), isEmpty);
    expect(event.hasSpecifiedSurfaces, isFalse);
    expect(event.referencesTooth(16), isTrue);
    expect(event.drawsOnTooth(16), isFalse);
  });

  test('bridge remains one event with explicit unit roles', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'bridge',
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Three-unit bridge',
      'bridgeUnits': [
        {'toothFdi': 14, 'role': 'abutment'},
        {'toothFdi': 15, 'role': 'pontic'},
        {'toothFdi': 16, 'role': 'implantAbutment'},
      ],
    });
    expect(event.validationErrors(), isEmpty);
    expect(event.referencesTooth(15), isTrue);
    expect(event.drawsOnTooth(15), isTrue);
    expect(OdontogramEvent.fromJson(event.toJson()).toJson(), event.toJson());
  });

  test('bridge may stay unmapped and therefore draws nothing', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'bridge',
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Historic bridge',
    });
    expect(event.validationErrors(), isEmpty);
    expect(event.drawsOnTooth(14), isFalse);
  });

  test('partial bridge mapping is rejected instead of being guessed', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'bridge',
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Bridge',
      'bridgeUnits': [
        {'toothFdi': 14, 'role': 'abutment'},
      ],
    });
    expect(event.validationErrors(), contains('bridgeUnits'));
  });

  test('removable prosthesis stores arch and optional components', () {
    final event = OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'removableProsthesis',
      'arch': 'upper',
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Upper partial denture',
      'removableComponents': [
        {'toothFdi': 14, 'role': 'clasp'},
        {'toothFdi': 15, 'role': 'replacedTooth'},
      ],
    });
    expect(event.validationErrors(), isEmpty);
    expect(event.arch, DentalArch.upper);
    expect(event.drawsOnTooth(14), isTrue);
    expect(event.drawsOnTooth(34), isFalse);
  });
}
