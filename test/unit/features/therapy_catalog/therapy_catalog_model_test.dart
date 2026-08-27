import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('therapy group preserves DentalWin provenance and presentation', () {
    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Endodontics',
      'displayOrder': 4,
      'colorValue': 0xFF246BCE,
      'sourceID': '43',
      'migration': {'source': 'DentalWin'},
    });
    expect(TherapyGroup.fromJson(group.toJson()).toJson(), group.toJson());
  });

  test('procedure distinguishes false, true, and unknown legacy flags', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Composite filling',
      'basePrice': '80.50',
      'toothRequired': 'true',
      'perToothPrice': null,
      'durationMinutes': '',
    });
    expect(item.basePrice, 80.5);
    expect(item.toothRequired, isTrue);
    expect(item.perToothPrice, isNull);
    expect(item.durationMinutes, isNull);
  });

  test('procedure preserves target and an editable surface shortcut', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Composite filling MO',
      'targetScope': 'tooth',
      'surfaceSelectionMode': 'optional',
      'defaultSurfaces': ['mesial', 'occlusalIncisal'],
    });
    expect(item.targetScope, TreatmentTargetScope.tooth);
    expect(item.surfaceSelectionMode, SurfaceSelectionMode.optional);
    expect(item.validationErrors(), isEmpty);
    expect(
      ProcedureCatalogItem.fromJson(item.toJson()).toJson(),
      item.toJson(),
    );
  });

  test('non-tooth catalogue target cannot carry a surface shortcut', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Bridge',
      'targetScope': 'bridge',
      'defaultSurfaces': ['mesial'],
    });
    expect(item.validationErrors(), contains('defaultSurfaces'));
  });
}
