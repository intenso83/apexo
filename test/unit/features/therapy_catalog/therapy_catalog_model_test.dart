import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/procedure_handling_classifier.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
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

  test('five-way handling mode is persisted and configures legacy fields', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Crown',
      'toothRequired': false,
    });
    item.applyHandlingMode(ProcedureHandlingMode.wholeTooth);

    expect(item.handlingMode, ProcedureHandlingMode.wholeTooth);
    expect(item.targetScope, TreatmentTargetScope.tooth);
    expect(item.toothRequired, isTrue);
    expect(
      item.surfaceSelectionMode,
      SurfaceSelectionMode.automaticWholeTooth,
    );
    expect(item.defaultSurfaces, ['wholeTooth']);
    expect(item.validationErrors(), isEmpty);
    expect(
      ProcedureCatalogItem.fromJson(item.toJson()).handlingMode,
      ProcedureHandlingMode.wholeTooth,
    );
  });

  test('classifier distinguishes the five imported catalogue workflows', () {
    expect(
      classifyProcedureHandling(
        procedureName: 'Έμφραξη σύνθετης ρητίνης',
        groupName: 'Χειρουργική οδοντική',
      ).mode,
      ProcedureHandlingMode.surfaceBased,
    );
    expect(
      classifyProcedureHandling(
        procedureName: 'Ενδοδοντική θεραπεία γομφίου',
        groupName: 'Ενδοδοντία',
      ).mode,
      ProcedureHandlingMode.wholeTooth,
    );
    expect(
      classifyProcedureHandling(
        procedureName: 'Γέφυρα Maryland',
        groupName: 'Ακίνητη Προσθετική',
      ).mode,
      ProcedureHandlingMode.bridge,
    );
    expect(
      classifyProcedureHandling(
        procedureName: 'Ολική οδοντοστοιχία',
        groupName: 'Κινητή Προσθετική',
      ).mode,
      ProcedureHandlingMode.removableProsthesis,
    );
    expect(
      classifyProcedureHandling(
        procedureName: 'Κλινική εξέταση',
        groupName: 'Διάγνωση',
      ).mode,
      ProcedureHandlingMode.patientLevel,
    );
  });

  test('ambiguous imported work uses safe patient-level review fallback', () {
    final decision = classifyProcedureHandling(
      procedureName: 'Παλαιά ειδική εργασία',
      groupName: 'Λοιπά',
    );
    expect(decision.mode, ProcedureHandlingMode.patientLevel);
    expect(decision.needsReview, isTrue);
  });

  test('recognized name wins over the old no-tooth import hint', () {
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    addTearDown(() {
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
    });
    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Ακίνητη Προσθετική',
    });
    final item = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Γέφυρα Maryland',
      'therapyGroupID': group.id,
      'toothRequired': false,
    });
    therapyGroups.set(group);
    procedureCatalog.set(item);

    expect(
      procedureCatalog.handlingDecision(item).mode,
      ProcedureHandlingMode.bridge,
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
