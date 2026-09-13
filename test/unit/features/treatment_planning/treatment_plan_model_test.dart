import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_completion.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    treatmentPlans.observableMap.clear();
    odontogramEvents.observableMap.clear();
  });

  tearDown(() {
    treatmentPlans.observableMap.clear();
    odontogramEvents.observableMap.clear();
  });

  test('plan round-trip preserves alternatives, consent, and snapshots', () {
    final plan = TreatmentPlan.fromJson({
      'id': 'plan12345678901',
      'patientID': 'patient1234567',
      'title': 'Alternative A',
      'language': 'de',
      'consentStatus': 'verbalAgreement',
      'consentTextEl': 'EL consent',
      'consentTextEn': 'EN consent',
      'consentTextDe': 'DE consent',
      'signedAttachmentName': 'signed-plan.pdf',
      'signedAttachmentBase64': 'c2lnbmVk',
      'wholeDiscountPercent': 10,
      'wholeDiscountAmount': 20,
      'items': [
        {
          'id': 'item12345678901',
          'procedureID': 'procedure123456',
          'procedureNameElSnapshot': 'Στεφάνη',
          'procedureNameEnSnapshot': 'Crown',
          'procedureNameDeSnapshot': 'Krone',
          'handlingMode': 'wholeTooth',
          'odontogramOverlay': 'crown',
          'unitPrice': 500,
          'quantity': 2,
          'discountPercent': 5,
          'discountAmount': 10,
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
          'laboratoryID': 'laboratory-1',
          'laboratoryNameSnapshot': 'Praxis Lab',
          'laboratoryCost': 85,
        },
      ],
    });

    expect(plan.items.single.displayName(TreatmentPlanLanguage.de), 'Krone');
    expect(plan.signedAttachmentName, 'signed-plan.pdf');
    expect(plan.signedAttachmentBase64, 'c2lnbmVk');
    expect(plan.items.single.laboratoryID, 'laboratory-1');
    expect(plan.items.single.laboratoryNameSnapshot, 'Praxis Lab');
    expect(plan.items.single.laboratoryCost, 85);
    expect(TreatmentPlan.fromJson(plan.toJson()).toJson(), plan.toJson());
  });

  test('internal percentages become monetary discounts in totals', () {
    final plan = TreatmentPlan.fromJson({
      'patientID': 'patient1234567',
      'wholeDiscountPercent': 10,
      'wholeDiscountAmount': 25,
      'items': [
        {
          'procedureID': 'procedure123456',
          'procedureNameElSnapshot': 'Treatment',
          'unitPrice': 100,
          'quantity': 2,
          'discountPercent': 10,
          'discountAmount': 5,
        },
      ],
    });

    expect(plan.gross, 200);
    expect(plan.itemDiscountTotal, 25);
    expect(plan.subtotal, 175);
    expect(plan.wholePercentageDiscount, 17.5);
    expect(plan.wholePlanDiscount, 42.5);
    expect(plan.totalDiscount, 67.5);
    expect(plan.total, 132.5);
  });

  test('one-off item retains its custom marker and free-text price', () {
    final item = TreatmentPlanItem.fromJson({
      'isCustom': true,
      'procedureID': '',
      'procedureNameElSnapshot': 'Ειδική εργασία',
      'unitPrice': 75,
      'quantity': 2,
      'discountAmount': 10,
      'handlingMode': 'patientLevel',
    });

    expect(item.isCustom, isTrue);
    expect(item.procedureID, isEmpty);
    expect(item.net, 140);
    expect(TreatmentPlanItem.fromJson(item.toJson()).toJson(), item.toJson());
    expect(TreatmentPlanItem.fromJson({'procedureID': 'catalogued'}).isCustom,
        isFalse);
  });

  test('completion creates a timestamped odontogram event without payment', () {
    final completedAt = DateTime(2026, 8, 30, 10, 45);
    final plan = TreatmentPlan.fromJson({
      'id': 'plan12345678901',
      'patientID': 'patient1234567',
      'title': 'Alternative A',
      'items': [
        {
          'id': 'item12345678901',
          'procedureID': 'procedure123456',
          'procedureNameElSnapshot': 'Ενδοδοντική θεραπεία',
          'therapyGroupID': 'group1234567890',
          'therapyGroupNameSnapshot': 'Ενδοδοντία',
          'handlingMode': 'wholeTooth',
          'odontogramOverlay': 'rootCanal',
          'unitPrice': 180,
          'toothFdi': 16,
          'surfaces': ['wholeTooth'],
          'laboratoryID': 'laboratory-1',
          'laboratoryNameSnapshot': 'Praxis Lab',
          'laboratoryCost': 70,
        },
      ],
    });
    treatmentPlans.set(plan);

    final event = completeTreatmentPlanItem(
      plan: plan,
      itemID: plan.items.single.id,
      completedAt: completedAt,
    );

    expect(event.status.name, 'completed');
    expect(event.recordedAt, completedAt);
    expect(event.toothFdi, 16);
    expect(event.surfaces, ['wholeTooth']);
    expect(event.overlayKind, OdontogramOverlayKind.rootCanal);
    expect(event.priceSnapshot, 180);
    expect(event.laboratoryID, 'laboratory-1');
    expect(event.laboratoryNameSnapshot, 'Praxis Lab');
    expect(event.laboratoryCost, 70);
    expect(event.migration['financialMutation'], isFalse);
    expect(plan.items.single.status, TreatmentPlanItemStatus.completed);
    expect(plan.items.single.odontogramEventID, event.id);
  });

  test('bridge item cannot complete without valid clinical mapping', () {
    final item = TreatmentPlanItem()
      ..handlingMode = ProcedureHandlingMode.bridge
      ..bridgeUnits = const [
        BridgeUnit(toothFdi: 14, role: BridgeUnitRole.abutment),
      ];
    expect(item.targetValidationErrors(), ['bridgeUnits']);
  });

  test('completing a one-off item keeps its description without a catalogue ID',
      () {
    final plan = TreatmentPlan.fromJson({
      'id': 'plan12345678901',
      'patientID': 'patient1234567',
      'items': [
        {
          'id': 'item12345678901',
          'isCustom': true,
          'procedureID': '',
          'procedureNameElSnapshot': 'Ειδική εργασία',
          'unitPrice': 80,
          'notes': 'Detailed description',
          'handlingMode': 'patientLevel',
        },
      ],
    });
    treatmentPlans.set(plan);

    final event = completeTreatmentPlanItem(
      plan: plan,
      itemID: plan.items.single.id,
      completedAt: DateTime(2026, 9, 12, 12),
    );

    expect(event.procedureID, isEmpty);
    expect(event.procedureNameSnapshot, 'Ειδική εργασία');
    expect(event.priceSnapshot, 80);
    expect(event.notes, 'Detailed description');
    expect(event.migration['source'], 'treatment_plan');
    expect(event.migration['isCustom'], isTrue);
    expect(event.migration['treatmentPlanItemID'], plan.items.single.id);
    expect(event.migration['financialMutation'], isFalse);
    expect(event.validationErrors(), isEmpty);
    expect(plan.items.single.status, TreatmentPlanItemStatus.completed);
    expect(plan.items.single.odontogramEventID, event.id);
  });
}
