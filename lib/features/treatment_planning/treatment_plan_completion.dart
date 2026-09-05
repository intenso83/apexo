import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';

import 'treatment_plan_model.dart';
import 'treatment_plan_store.dart';

class TreatmentPlanCompletionException implements Exception {
  TreatmentPlanCompletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

OdontogramEvent completeTreatmentPlanItem({
  required TreatmentPlan plan,
  required String itemID,
  DateTime? completedAt,
}) {
  final itemIndex = plan.items.indexWhere((item) => item.id == itemID);
  if (itemIndex < 0) {
    throw TreatmentPlanCompletionException('Treatment-plan item not found.');
  }
  final item = plan.items[itemIndex];
  if (item.isCompleted) {
    throw TreatmentPlanCompletionException(
      'This treatment-plan item is already completed.',
    );
  }
  final targetErrors = item.targetValidationErrors();
  if (targetErrors.isNotEmpty) {
    throw TreatmentPlanCompletionException(
      'Complete the treatment target before marking this item done.',
    );
  }

  final now = completedAt ?? DateTime.now();
  final event = OdontogramEvent.fromJson({
    'patientID': plan.patientID,
    'targetScope': item.targetScope.name,
    if (item.toothFdi != null) 'toothFdi': item.toothFdi,
    if (item.surfaces.isNotEmpty) 'surfaces': item.surfaces,
    if (item.bridgeUnits.isNotEmpty)
      'bridgeUnits': item.bridgeUnits.map((unit) => unit.toJson()).toList(),
    if (item.arch.name != 'unspecified') 'arch': item.arch.name,
    if (item.removableComponents.isNotEmpty)
      'removableComponents': item.removableComponents
          .map((component) => component.toJson())
          .toList(),
    'procedureID': item.procedureID,
    'procedureNameSnapshot': item.procedureNameElSnapshot,
    'therapyGroupID': item.therapyGroupID,
    'therapyGroupNameSnapshot': item.therapyGroupNameSnapshot,
    if (item.odontogramOverlay != null)
      'overlayKind': item.odontogramOverlay!.name,
    'priceSnapshot': item.net,
    'eventKind': OdontogramEventKind.treatment.name,
    'status': OdontogramEventStatus.completed.name,
    'recordedAt': (now.millisecondsSinceEpoch / 60000).round(),
    if (item.notes.isNotEmpty) 'notes': item.notes,
    if (item.laboratoryID.isNotEmpty) 'laboratoryID': item.laboratoryID,
    if (item.laboratoryNameSnapshot.isNotEmpty)
      'laboratoryNameSnapshot': item.laboratoryNameSnapshot,
    if (item.laboratoryCost != 0) 'laboratoryCost': item.laboratoryCost,
    'migration': {
      'source': 'treatment_plan',
      'treatmentPlanID': plan.id,
      'treatmentPlanItemID': item.id,
      'financialMutation': false,
    },
  });
  final errors = event.validationErrors();
  if (errors.isNotEmpty) {
    throw TreatmentPlanCompletionException(
      'The completed treatment is missing: ${errors.join(', ')}.',
    );
  }

  odontogramEvents.set(event);
  item.status = TreatmentPlanItemStatus.completed;
  item.completedAt = now;
  item.odontogramEventID = event.id;
  plan.items[itemIndex] = item;
  treatmentPlans.set(plan);
  return event;
}
