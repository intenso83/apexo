import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/procedure_handling_classifier.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
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
      'defaultDrawingBehavior': 'filling',
      'defaultMaterialColorArgb': 0xFFAA5500,
    });
    expect(item.targetScope, TreatmentTargetScope.tooth);
    expect(item.surfaceSelectionMode, SurfaceSelectionMode.optional);
    expect(item.validationErrors(), isEmpty);
    expect(item.defaultDrawingBehavior, OdontogramDrawingBehavior.filling);
    expect(item.defaultMaterialColorArgb, 0xFFAA5500);
    expect(
      ProcedureCatalogItem.fromJson(item.toJson()).toJson(),
      item.toJson(),
    );
  });

  test('procedure preserves a cervical surface preset independently', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Cervical composite',
      'targetScope': 'tooth',
      'defaultSurfaces': ['facial'],
      'defaultCervicalSurfaces': ['facial'],
    });
    expect(item.validationErrors(), isEmpty);
    expect(
      ProcedureCatalogItem.fromJson(item.toJson()).defaultCervicalSurfaces,
      ['facial'],
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

  test('procedure preserves an explicit odontogram symbol override', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Special restoration',
      'odontogramOverlay': 'crown',
    });
    expect(item.odontogramOverlay, OdontogramOverlayKind.crown);
    expect(
      ProcedureCatalogItem.fromJson(item.toJson()).odontogramOverlay,
      OdontogramOverlayKind.crown,
    );

    item.odontogramOverlay = OdontogramOverlayKind.none;
    expect(item.toJson()['odontogramOverlay'], 'none');
  });

  test('laboratory requirement is explicit or inferred for prosthetics', () {
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    addTearDown(() {
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
    });
    final group = TherapyGroup.fromJson({
      'id': 'prosthetic-group',
      'name': 'Ακίνητη Προσθετική',
    });
    therapyGroups.set(group);
    final crown = ProcedureCatalogItem.fromJson({
      'id': 'crown-procedure',
      'name': 'Στεφάνη ζιρκονίας',
      'therapyGroupID': group.id,
    });
    expect(procedureCatalog.requiresLaboratory(crown), isTrue);

    crown.requiresLaboratory = false;
    final restored = ProcedureCatalogItem.fromJson(crown.toJson());
    expect(restored.requiresLaboratory, isFalse);
    expect(procedureCatalog.requiresLaboratory(restored), isFalse);
  });

  test('labworks catalogue contains only therapies marked for laboratory use',
      () {
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    addTearDown(() {
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
    });
    final group = TherapyGroup.fromJson({
      'id': 'mixed-group',
      'name': 'Treatments',
    });
    therapyGroups.set(group);
    final filling = ProcedureCatalogItem.fromJson({
      'id': 'filling',
      'name': 'Filling',
      'therapyGroupID': group.id,
      'requiresLaboratory': false,
    });
    final crown = ProcedureCatalogItem.fromJson({
      'id': 'crown',
      'name': 'Crown',
      'therapyGroupID': group.id,
      'requiresLaboratory': true,
    });
    procedureCatalog.setAll([filling, crown]);

    expect(
      procedureCatalog.laboratoryProcedures.map((item) => item.id),
      ['crown'],
    );
  });

  test('overlay classifier distinguishes common clinical symbols', () {
    expect(
      inferOdontogramOverlay(
        procedureName: 'Ενδοδοντική θεραπεία γομφίου',
        groupName: 'Ενδοδοντία',
      ),
      OdontogramOverlayKind.rootCanal,
    );
    expect(
      inferOdontogramOverlay(
        procedureName: 'Συγκόλληση στεφάνης',
        groupName: 'Ενδοδοντία',
      ),
      OdontogramOverlayKind.crown,
    );
    expect(
      inferOdontogramOverlay(
        procedureName: 'Εξαγωγή',
        groupName: 'Χειρουργική',
      ),
      OdontogramOverlayKind.extraction,
    );
    expect(
      inferOdontogramOverlay(
        procedureName: 'Τοποθέτηση εμφυτεύματος',
        groupName: 'Εμφυτεύματα',
      ),
      OdontogramOverlayKind.implant,
    );
    expect(
      inferOdontogramOverlay(
        procedureName: 'Unrecognized bridge item',
        groupName: 'Miscellaneous',
        targetScope: TreatmentTargetScope.bridge,
      ),
      OdontogramOverlayKind.bridge,
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
        procedureName: 'Στεφάνη ζιρκονίας / μεταλλοκεραμική',
        groupName: 'Ακίνητη Προσθετική',
      ).mode,
      ProcedureHandlingMode.wholeTooth,
    );
    expect(
      inferOdontogramOverlay(
        procedureName: 'Στεφάνη ζιρκονίας / μεταλλοκεραμική',
        groupName: 'Ακίνητη Προσθετική',
      ),
      OdontogramOverlayKind.crown,
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

  test('verified imported surface defaults outrank translated-name guessing',
      () {
    final item = ProcedureCatalogItem.fromJson({
      'sourceCode': '86107',
      'name': 'Ανασύσταση κοπτικής γωνίας m',
      'toothRequired': true,
      'defaultDrawingBehavior': 'filling',
      'defaultSurfaces': ['mesial', 'facial'],
    });

    final decision = procedureCatalog.handlingDecision(item);
    expect(decision.mode, ProcedureHandlingMode.surfaceBased);
    expect(decision.inferred, isTrue);
    expect(decision.needsReview, isFalse);
    expect(decision.rule, 'structured_filling_defaults');
    expect(procedureCatalog.overlayFor(item), OdontogramOverlayKind.filling);
  });

  test('invalid imported filling defaults remain in the review fallback', () {
    final item = ProcedureCatalogItem.fromJson({
      'sourceCode': '86107',
      'name': 'Ανασύσταση κοπτικής γωνίας m',
      'toothRequired': true,
      'defaultDrawingBehavior': 'filling',
      'defaultSurfaces': ['unknown'],
    });

    final decision = procedureCatalog.handlingDecision(item);
    expect(decision.mode, ProcedureHandlingMode.patientLevel);
    expect(decision.needsReview, isTrue);
    expect(decision.rule, 'safe_fallback');
  });

  test('explicit user handling and overlay override structured import hints',
      () {
    final item = ProcedureCatalogItem.fromJson({
      'sourceCode': '86107',
      'name': 'Ανασύσταση κοπτικής γωνίας m',
      'handlingMode': 'patientLevel',
      'odontogramOverlay': 'none',
      'toothRequired': true,
      'defaultDrawingBehavior': 'filling',
      'defaultSurfaces': ['mesial', 'facial'],
    });

    final decision = procedureCatalog.handlingDecision(item);
    expect(decision.mode, ProcedureHandlingMode.patientLevel);
    expect(decision.inferred, isFalse);
    expect(decision.rule, 'explicit');
    expect(procedureCatalog.overlayFor(item), OdontogramOverlayKind.none);
  });

  test('verified crown drawing supplies a whole-tooth compatibility mode', () {
    final item = ProcedureCatalogItem.fromJson({
      'name': 'Legacy translated label',
      'defaultDrawingBehavior': 'crown',
    });

    final decision = procedureCatalog.handlingDecision(item);
    expect(decision.mode, ProcedureHandlingMode.wholeTooth);
    expect(decision.needsReview, isFalse);
    expect(decision.rule, 'structured_whole_tooth_drawing');
    expect(procedureCatalog.overlayFor(item), OdontogramOverlayKind.crown);
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
