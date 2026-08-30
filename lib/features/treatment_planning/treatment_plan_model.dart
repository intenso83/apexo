import 'package:apexo/core/model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/utils/uuid.dart';

enum TreatmentPlanLanguage { el, en, de }

enum TreatmentPlanConsentStatus {
  notAgreed,
  verbalAgreement,
  signedAgreement,
}

enum TreatmentPlanItemStatus { planned, completed, cancelled }

class TreatmentPlanItem {
  TreatmentPlanItem({String? id}) : id = id ?? uuid();

  String id;
  String procedureID = '';
  String procedureNameElSnapshot = '';
  String procedureNameEnSnapshot = '';
  String procedureNameDeSnapshot = '';
  String therapyGroupID = '';
  String therapyGroupNameSnapshot = '';
  ProcedureHandlingMode handlingMode = ProcedureHandlingMode.patientLevel;
  OdontogramOverlayKind? odontogramOverlay;
  double unitPrice = 0;
  int quantity = 1;
  double discountPercent = 0;
  double discountAmount = 0;
  TreatmentPlanItemStatus status = TreatmentPlanItemStatus.planned;
  int? toothFdi;
  List<String> surfaces = [];
  List<BridgeUnit> bridgeUnits = [];
  DentalArch arch = DentalArch.unspecified;
  List<RemovableComponent> removableComponents = [];
  String notes = '';
  DateTime? completedAt;
  String odontogramEventID = '';

  factory TreatmentPlanItem.fromJson(Map<String, dynamic> json) {
    final item = TreatmentPlanItem(id: json['id']?.toString());
    item.procedureID = json['procedureID']?.toString() ?? '';
    item.procedureNameElSnapshot =
        json['procedureNameElSnapshot']?.toString() ?? '';
    item.procedureNameEnSnapshot =
        json['procedureNameEnSnapshot']?.toString() ?? '';
    item.procedureNameDeSnapshot =
        json['procedureNameDeSnapshot']?.toString() ?? '';
    item.therapyGroupID = json['therapyGroupID']?.toString() ?? '';
    item.therapyGroupNameSnapshot =
        json['therapyGroupNameSnapshot']?.toString() ?? '';
    item.handlingMode = enumByName(
      ProcedureHandlingMode.values,
      json['handlingMode'],
      ProcedureHandlingMode.patientLevel,
    );
    item.odontogramOverlay = nullableEnumByName(
      OdontogramOverlayKind.values,
      json['odontogramOverlay'],
    );
    item.unitPrice = _asDouble(json['unitPrice']);
    item.quantity = _asInt(json['quantity'], 1).clamp(1, 999);
    item.discountPercent = _asDouble(json['discountPercent']);
    item.discountAmount = _asDouble(json['discountAmount']);
    item.status = enumByName(
      TreatmentPlanItemStatus.values,
      json['status'],
      TreatmentPlanItemStatus.planned,
    );
    item.toothFdi = _asNullableInt(json['toothFdi']);
    item.surfaces = List<String>.from(json['surfaces'] ?? const <String>[]);
    item.bridgeUnits = _mapList(json['bridgeUnits'], BridgeUnit.fromJson);
    item.arch = enumByName(DentalArch.values, json['arch'], item.arch);
    item.removableComponents = _mapList(
      json['removableComponents'],
      RemovableComponent.fromJson,
    );
    item.notes = json['notes']?.toString() ?? '';
    item.completedAt = _dateFromMinuteEpoch(json['completedAt']);
    item.odontogramEventID = json['odontogramEventID']?.toString() ?? '';
    return item;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'procedureID': procedureID,
        'procedureNameElSnapshot': procedureNameElSnapshot,
        if (procedureNameEnSnapshot.isNotEmpty)
          'procedureNameEnSnapshot': procedureNameEnSnapshot,
        if (procedureNameDeSnapshot.isNotEmpty)
          'procedureNameDeSnapshot': procedureNameDeSnapshot,
        if (therapyGroupID.isNotEmpty) 'therapyGroupID': therapyGroupID,
        if (therapyGroupNameSnapshot.isNotEmpty)
          'therapyGroupNameSnapshot': therapyGroupNameSnapshot,
        'handlingMode': handlingMode.name,
        if (odontogramOverlay != null)
          'odontogramOverlay': odontogramOverlay!.name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        if (discountPercent != 0) 'discountPercent': discountPercent,
        if (discountAmount != 0) 'discountAmount': discountAmount,
        'status': status.name,
        if (toothFdi != null) 'toothFdi': toothFdi,
        if (surfaces.isNotEmpty) 'surfaces': surfaces,
        if (bridgeUnits.isNotEmpty)
          'bridgeUnits': bridgeUnits.map((unit) => unit.toJson()).toList(),
        if (arch != DentalArch.unspecified) 'arch': arch.name,
        if (removableComponents.isNotEmpty)
          'removableComponents': removableComponents
              .map((component) => component.toJson())
              .toList(),
        if (notes.isNotEmpty) 'notes': notes,
        if (completedAt != null)
          'completedAt': (completedAt!.millisecondsSinceEpoch / 60000).round(),
        if (odontogramEventID.isNotEmpty)
          'odontogramEventID': odontogramEventID,
      };

  TreatmentPlanItem copy() => TreatmentPlanItem.fromJson(toJson());

  TreatmentTargetScope get targetScope => handlingMode.targetScope;

  double get gross => unitPrice.clamp(0, double.infinity).toDouble() * quantity;

  double get percentageDiscount => gross * discountPercent.clamp(0, 100) / 100;

  double get monetaryDiscount {
    final remaining = (gross - percentageDiscount).clamp(0, double.infinity);
    return (percentageDiscount + discountAmount.clamp(0, remaining))
        .clamp(0, gross);
  }

  double get net => (gross - monetaryDiscount).clamp(0, double.infinity);

  bool get isCompleted => status == TreatmentPlanItemStatus.completed;

  String displayName(TreatmentPlanLanguage language) => switch (language) {
        TreatmentPlanLanguage.el => procedureNameElSnapshot,
        TreatmentPlanLanguage.en => procedureNameEnSnapshot.isEmpty
            ? procedureNameElSnapshot
            : procedureNameEnSnapshot,
        TreatmentPlanLanguage.de => procedureNameDeSnapshot.isEmpty
            ? procedureNameElSnapshot
            : procedureNameDeSnapshot,
      };

  List<String> targetValidationErrors() {
    switch (targetScope) {
      case TreatmentTargetScope.patient:
        return const [];
      case TreatmentTargetScope.tooth:
        return toothFdi != null && isPermanentFdi(toothFdi!)
            ? const []
            : const ['toothFdi'];
      case TreatmentTargetScope.bridge:
        if (bridgeUnits.length < 2 ||
            bridgeUnits.map((unit) => unit.toothFdi).toSet().length !=
                bridgeUnits.length ||
            bridgeUnits.any((unit) => !isPermanentFdi(unit.toothFdi)) ||
            !bridgeUnits.any((unit) => unit.role == BridgeUnitRole.pontic) ||
            !bridgeUnits.any((unit) =>
                unit.role == BridgeUnitRole.abutment ||
                unit.role == BridgeUnitRole.implantAbutment)) {
          return const ['bridgeUnits'];
        }
        return const [];
      case TreatmentTargetScope.removableProsthesis:
        if (arch == DentalArch.unspecified ||
            removableComponents.any((component) =>
                !isPermanentFdi(component.toothFdi) ||
                !archContainsTooth(arch, component.toothFdi))) {
          return const ['removableComponents'];
        }
        return const [];
    }
  }
}

class TreatmentPlan extends Model {
  String patientID = '';
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  TreatmentPlanLanguage language = TreatmentPlanLanguage.el;
  TreatmentPlanConsentStatus consentStatus =
      TreatmentPlanConsentStatus.notAgreed;
  DateTime? consentRecordedAt;
  String consentTextEl = '';
  String consentTextEn = '';
  String consentTextDe = '';
  String signedAttachmentName = '';
  String signedAttachmentPath = '';
  String signedAttachmentBase64 = '';
  double wholeDiscountPercent = 0;
  double wholeDiscountAmount = 0;
  List<TreatmentPlanItem> items = [];

  TreatmentPlan.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID']?.toString() ?? patientID;
    createdAt = _dateFromMinuteEpoch(json['createdAt']) ?? createdAt;
    updatedAt = _dateFromMinuteEpoch(json['updatedAt']) ?? updatedAt;
    language = enumByName(
      TreatmentPlanLanguage.values,
      json['language'],
      language,
    );
    consentStatus = enumByName(
      TreatmentPlanConsentStatus.values,
      json['consentStatus'],
      consentStatus,
    );
    consentRecordedAt = _dateFromMinuteEpoch(json['consentRecordedAt']);
    consentTextEl = json['consentTextEl']?.toString() ?? consentTextEl;
    consentTextEn = json['consentTextEn']?.toString() ?? consentTextEn;
    consentTextDe = json['consentTextDe']?.toString() ?? consentTextDe;
    signedAttachmentName =
        json['signedAttachmentName']?.toString() ?? signedAttachmentName;
    signedAttachmentPath =
        json['signedAttachmentPath']?.toString() ?? signedAttachmentPath;
    signedAttachmentBase64 =
        json['signedAttachmentBase64']?.toString() ?? signedAttachmentBase64;
    wholeDiscountPercent = _asDouble(json['wholeDiscountPercent']);
    wholeDiscountAmount = _asDouble(json['wholeDiscountAmount']);
    items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) =>
            TreatmentPlanItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['patientID'] = patientID;
    json['createdAt'] = (createdAt.millisecondsSinceEpoch / 60000).round();
    json['updatedAt'] = (updatedAt.millisecondsSinceEpoch / 60000).round();
    json['language'] = language.name;
    json['consentStatus'] = consentStatus.name;
    if (consentRecordedAt != null) {
      json['consentRecordedAt'] =
          (consentRecordedAt!.millisecondsSinceEpoch / 60000).round();
    }
    if (consentTextEl.isNotEmpty) json['consentTextEl'] = consentTextEl;
    if (consentTextEn.isNotEmpty) json['consentTextEn'] = consentTextEn;
    if (consentTextDe.isNotEmpty) json['consentTextDe'] = consentTextDe;
    if (signedAttachmentName.isNotEmpty) {
      json['signedAttachmentName'] = signedAttachmentName;
    }
    if (signedAttachmentPath.isNotEmpty) {
      json['signedAttachmentPath'] = signedAttachmentPath;
    }
    if (signedAttachmentBase64.isNotEmpty) {
      json['signedAttachmentBase64'] = signedAttachmentBase64;
    }
    if (wholeDiscountPercent != 0) {
      json['wholeDiscountPercent'] = wholeDiscountPercent;
    }
    if (wholeDiscountAmount != 0) {
      json['wholeDiscountAmount'] = wholeDiscountAmount;
    }
    json['items'] = items.map((item) => item.toJson()).toList();
    return json;
  }

  @override
  TreatmentPlan copy(bool blank) =>
      TreatmentPlan.fromJson(blank ? <String, dynamic>{} : toJson());

  double get gross => items.fold(0, (sum, item) => sum + item.gross);

  double get itemDiscountTotal =>
      items.fold(0, (sum, item) => sum + item.monetaryDiscount);

  double get subtotal => (gross - itemDiscountTotal).clamp(0, double.infinity);

  double get wholePercentageDiscount =>
      subtotal * wholeDiscountPercent.clamp(0, 100) / 100;

  double get wholePlanDiscount {
    final remaining =
        (subtotal - wholePercentageDiscount).clamp(0, double.infinity);
    return (wholePercentageDiscount + wholeDiscountAmount.clamp(0, remaining))
        .clamp(0, subtotal);
  }

  double get totalDiscount => itemDiscountTotal + wholePlanDiscount;

  double get total => (gross - totalDiscount).clamp(0, double.infinity);

  String consentText(TreatmentPlanLanguage selectedLanguage) =>
      switch (selectedLanguage) {
        TreatmentPlanLanguage.el => consentTextEl,
        TreatmentPlanLanguage.en => consentTextEn,
        TreatmentPlanLanguage.de => consentTextDe,
      };
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value, int fallback) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null || value == '') return null;
  return _asInt(value, 0);
}

DateTime? _dateFromMinuteEpoch(dynamic value) {
  final minutes = value == null ? null : _asInt(value, 0);
  if (minutes == null || minutes <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(minutes * 60000);
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) mapper,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList();
}
