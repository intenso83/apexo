import 'package:apexo/core/model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';

class TreatmentHistoryEntry extends Model {
  String patientID = '';
  String treatmentName = '';
  String eventKind = 'clinical_event';
  DateTime? date;
  String dateRaw = '';
  String toothFdi = '';
  String toothRaw = '';
  String sourceTable = '';
  String sourceRecordKey = '';
  String chartRole = '';
  List<String> surfaces = [];
  List<String> cervicalSurfaces = [];
  OdontogramDrawingBehavior? drawingBehavior;
  int? materialColorArgb;
  String notes = '';
  String statusRaw = '';
  String chargeRaw = '';
  String creditRaw = '';
  String totalRaw = '';
  String sourceCatalogCode = '';
  String catalogLinkMethod = 'legacy_custom';
  String therapyGroup = '';
  Map<String, dynamic> migration = {};

  bool get isTreatmentPlanItem => eventKind == 'treatment_plan_item';
  bool get isCompletedTreatment => !isTreatmentPlanItem;
  bool get hasMappedCatalog => catalogLinkMethod != 'legacy_custom';
  String get displayedTooth => toothFdi.isNotEmpty ? toothFdi : toothRaw;

  TreatmentHistoryEntry.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID'] ?? patientID;
    treatmentName = json['treatmentName'] ?? json['title'] ?? treatmentName;
    eventKind = json['eventKind'] ?? eventKind;
    final dateValue = json['date'];
    if (dateValue is num && dateValue > 0) {
      date = DateTime.fromMillisecondsSinceEpoch((dateValue * 60000).round());
    }
    dateRaw = json['dateRaw']?.toString() ?? dateRaw;
    toothFdi = json['toothFdi']?.toString() ?? toothFdi;
    toothRaw = json['toothRaw']?.toString() ?? toothRaw;
    sourceTable = json['sourceTable']?.toString() ?? sourceTable;
    sourceRecordKey = json['sourceRecordKey']?.toString() ?? sourceRecordKey;
    chartRole = json['chartRole']?.toString() ?? chartRole;
    surfaces = List<String>.from(json['surfaces'] ?? const <String>[]);
    cervicalSurfaces =
        List<String>.from(json['cervicalSurfaces'] ?? const <String>[]);
    drawingBehavior = _drawingBehaviorByName(json['drawingBehavior']);
    materialColorArgb = _asNullableInt(json['materialColorArgb']);
    notes = json['notes']?.toString() ?? notes;
    statusRaw = json['statusRaw']?.toString() ?? statusRaw;
    chargeRaw = json['chargeRaw']?.toString() ?? chargeRaw;
    creditRaw = json['creditRaw']?.toString() ?? creditRaw;
    totalRaw = json['totalRaw']?.toString() ?? totalRaw;
    sourceCatalogCode =
        json['sourceCatalogCode']?.toString() ?? sourceCatalogCode;
    catalogLinkMethod =
        json['catalogLinkMethod']?.toString() ?? catalogLinkMethod;
    therapyGroup = json['therapyGroup']?.toString() ?? therapyGroup;
    migration = Map<String, dynamic>.from(json['migration'] ?? migration);
    if (title.isEmpty) title = treatmentName;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['patientID'] = patientID;
    json['treatmentName'] = treatmentName;
    json['eventKind'] = eventKind;
    if (date != null) {
      json['date'] = (date!.millisecondsSinceEpoch / 60000).round();
    }
    if (dateRaw.isNotEmpty) json['dateRaw'] = dateRaw;
    if (toothFdi.isNotEmpty) json['toothFdi'] = toothFdi;
    if (toothRaw.isNotEmpty) json['toothRaw'] = toothRaw;
    if (sourceTable.isNotEmpty) json['sourceTable'] = sourceTable;
    if (sourceRecordKey.isNotEmpty) {
      json['sourceRecordKey'] = sourceRecordKey;
    }
    if (chartRole.isNotEmpty) json['chartRole'] = chartRole;
    if (surfaces.isNotEmpty) json['surfaces'] = surfaces;
    if (cervicalSurfaces.isNotEmpty) {
      json['cervicalSurfaces'] = cervicalSurfaces;
    }
    if (drawingBehavior != null) {
      json['drawingBehavior'] = drawingBehavior!.name;
    }
    if (materialColorArgb != null) {
      json['materialColorArgb'] = materialColorArgb;
    }
    if (notes.isNotEmpty) json['notes'] = notes;
    if (statusRaw.isNotEmpty) json['statusRaw'] = statusRaw;
    if (chargeRaw.isNotEmpty) json['chargeRaw'] = chargeRaw;
    if (creditRaw.isNotEmpty) json['creditRaw'] = creditRaw;
    if (totalRaw.isNotEmpty) json['totalRaw'] = totalRaw;
    if (sourceCatalogCode.isNotEmpty) {
      json['sourceCatalogCode'] = sourceCatalogCode;
    }
    json['catalogLinkMethod'] = catalogLinkMethod;
    if (therapyGroup.isNotEmpty) json['therapyGroup'] = therapyGroup;
    if (migration.isNotEmpty) json['migration'] = migration;
    return json;
  }

  @override
  TreatmentHistoryEntry copy(bool blank) {
    return TreatmentHistoryEntry.fromJson(blank ? {} : toJson());
  }
}

OdontogramDrawingBehavior? _drawingBehaviorByName(Object? value) {
  final name = value?.toString();
  if (name == null || name.isEmpty) return null;
  for (final behavior in OdontogramDrawingBehavior.values) {
    if (behavior.name == name) return behavior;
  }
  return null;
}

int? _asNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
