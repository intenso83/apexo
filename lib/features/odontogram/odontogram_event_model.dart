import 'package:apexo/core/model.dart';

import 'treatment_target.dart';

enum OdontogramEventKind { condition, treatment }

enum OdontogramEventStatus {
  existing,
  monitor,
  planned,
  completed,
  cancelled,
}

class OdontogramEvent extends Model {
  String patientID = '';
  TreatmentTargetScope targetScope = TreatmentTargetScope.tooth;
  int? toothFdi;
  List<String> surfaces = [];
  List<BridgeUnit> bridgeUnits = [];
  DentalArch arch = DentalArch.unspecified;
  List<RemovableComponent> removableComponents = [];
  String procedureID = '';
  String procedureNameSnapshot = '';
  String therapyGroupID = '';
  String therapyGroupNameSnapshot = '';
  double? priceSnapshot;
  OdontogramEventKind eventKind = OdontogramEventKind.treatment;
  OdontogramEventStatus status = OdontogramEventStatus.planned;
  DateTime recordedAt = DateTime.now();
  String appointmentID = '';
  String notes = '';
  String supersedesEventID = '';
  Map<String, dynamic> migration = {};

  OdontogramEvent.fromJson(super.json) : super.fromJson();

  bool get hasSpecifiedSurfaces => surfaces.isNotEmpty;
  bool get isLegacyWholeTooth => migration.isNotEmpty && surfaces.isEmpty;

  bool referencesTooth(int fdi) {
    return switch (targetScope) {
      TreatmentTargetScope.patient => false,
      TreatmentTargetScope.tooth => toothFdi == fdi,
      TreatmentTargetScope.bridge =>
        bridgeUnits.any((unit) => unit.toothFdi == fdi),
      TreatmentTargetScope.removableProsthesis => removableComponents.isEmpty
          ? archContainsTooth(arch, fdi)
          : removableComponents.any((component) => component.toothFdi == fdi),
    };
  }

  /// Whether this event has enough explicit location data to draw a marker.
  ///
  /// A tooth treatment with no selected surface remains in the timeline but
  /// deliberately does not paint or badge the tooth.
  bool drawsOnTooth(int fdi) {
    return switch (targetScope) {
      TreatmentTargetScope.patient => false,
      TreatmentTargetScope.tooth => toothFdi == fdi && surfaces.isNotEmpty,
      TreatmentTargetScope.bridge =>
        bridgeUnits.any((unit) => unit.toothFdi == fdi),
      TreatmentTargetScope.removableProsthesis =>
        removableComponents.any((component) => component.toothFdi == fdi),
    };
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID']?.toString() ?? patientID;
    toothFdi = _asNullableInt(json['toothFdi']);
    surfaces = List<String>.from(json['surfaces'] ?? const <String>[]);
    bridgeUnits = _mapList(json['bridgeUnits'], BridgeUnit.fromJson);
    arch = enumByName(DentalArch.values, json['arch'], arch);
    removableComponents = _mapList(
      json['removableComponents'],
      RemovableComponent.fromJson,
    );
    targetScope = nullableEnumByName(
          TreatmentTargetScope.values,
          json['targetScope'],
        ) ??
        _inferLegacyScope();
    procedureID = json['procedureID']?.toString() ?? procedureID;
    procedureNameSnapshot = json['procedureNameSnapshot']?.toString() ?? title;
    title = procedureNameSnapshot;
    therapyGroupID = json['therapyGroupID']?.toString() ?? therapyGroupID;
    therapyGroupNameSnapshot = json['therapyGroupNameSnapshot']?.toString() ??
        therapyGroupNameSnapshot;
    priceSnapshot = _asNullableDouble(json['priceSnapshot']);
    eventKind = enumByName(
      OdontogramEventKind.values,
      json['eventKind'],
      eventKind,
    );
    status = enumByName(
      OdontogramEventStatus.values,
      json['status'],
      status,
    );
    final minuteEpoch = _asNullableInt(json['recordedAt']);
    if (minuteEpoch != null) {
      recordedAt = DateTime.fromMillisecondsSinceEpoch(minuteEpoch * 60000);
    }
    appointmentID = json['appointmentID']?.toString() ?? appointmentID;
    notes = json['notes']?.toString() ?? notes;
    supersedesEventID =
        json['supersedesEventID']?.toString() ?? supersedesEventID;
    migration = Map<String, dynamic>.from(json['migration'] ?? migration);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['patientID'] = patientID;
    json['targetScope'] = targetScope.name;
    if (toothFdi != null) json['toothFdi'] = toothFdi;
    if (surfaces.isNotEmpty) json['surfaces'] = surfaces;
    if (bridgeUnits.isNotEmpty) {
      json['bridgeUnits'] = bridgeUnits.map((unit) => unit.toJson()).toList();
    }
    if (targetScope == TreatmentTargetScope.removableProsthesis ||
        arch != DentalArch.unspecified) {
      json['arch'] = arch.name;
    }
    if (removableComponents.isNotEmpty) {
      json['removableComponents'] =
          removableComponents.map((component) => component.toJson()).toList();
    }
    if (procedureID.isNotEmpty) json['procedureID'] = procedureID;
    json['procedureNameSnapshot'] = procedureNameSnapshot;
    if (therapyGroupID.isNotEmpty) json['therapyGroupID'] = therapyGroupID;
    if (therapyGroupNameSnapshot.isNotEmpty) {
      json['therapyGroupNameSnapshot'] = therapyGroupNameSnapshot;
    }
    if (priceSnapshot != null) json['priceSnapshot'] = priceSnapshot;
    json['eventKind'] = eventKind.name;
    json['status'] = status.name;
    json['recordedAt'] = (recordedAt.millisecondsSinceEpoch / 60000).round();
    if (appointmentID.isNotEmpty) json['appointmentID'] = appointmentID;
    if (notes.isNotEmpty) json['notes'] = notes;
    if (supersedesEventID.isNotEmpty) {
      json['supersedesEventID'] = supersedesEventID;
    }
    if (migration.isNotEmpty) json['migration'] = migration;
    return json;
  }

  List<String> validationErrors() {
    final errors = <String>[];
    if (patientID.isEmpty) errors.add('patientID');
    if (procedureNameSnapshot.trim().isEmpty) errors.add('procedure');
    if (eventKind == OdontogramEventKind.treatment && procedureID.isEmpty) {
      errors.add('procedureID');
    }
    if (toothFdi != null && !isPermanentFdi(toothFdi!)) {
      errors.add('toothFdi');
    }
    const validSurfaces = {
      'mesial',
      'distal',
      'facial',
      'oral',
      'occlusalIncisal',
      'wholeTooth',
    };
    if (surfaces.any((surface) => !validSurfaces.contains(surface))) {
      errors.add('surfaces');
    }
    if (surfaces.contains('wholeTooth') && surfaces.length > 1) {
      errors.add('surfaces');
    }
    switch (targetScope) {
      case TreatmentTargetScope.patient:
        if (toothFdi != null ||
            surfaces.isNotEmpty ||
            bridgeUnits.isNotEmpty ||
            removableComponents.isNotEmpty ||
            arch != DentalArch.unspecified) {
          errors.add('targetScope');
        }
      case TreatmentTargetScope.tooth:
        if (toothFdi == null) errors.add('toothFdi');
        if (bridgeUnits.isNotEmpty ||
            removableComponents.isNotEmpty ||
            arch != DentalArch.unspecified) {
          errors.add('targetScope');
        }
      case TreatmentTargetScope.bridge:
        if (toothFdi != null ||
            surfaces.isNotEmpty ||
            removableComponents.isNotEmpty ||
            arch != DentalArch.unspecified) {
          errors.add('targetScope');
        }
        errors.addAll(_bridgeValidationErrors());
      case TreatmentTargetScope.removableProsthesis:
        if (toothFdi != null || surfaces.isNotEmpty || bridgeUnits.isNotEmpty) {
          errors.add('targetScope');
        }
        errors.addAll(_removableValidationErrors());
    }
    return errors;
  }

  @override
  OdontogramEvent copy(bool blank) =>
      OdontogramEvent.fromJson(blank ? <String, dynamic>{} : toJson());

  TreatmentTargetScope _inferLegacyScope() {
    if (bridgeUnits.isNotEmpty) return TreatmentTargetScope.bridge;
    if (removableComponents.isNotEmpty || arch != DentalArch.unspecified) {
      return TreatmentTargetScope.removableProsthesis;
    }
    if (toothFdi != null) return TreatmentTargetScope.tooth;
    return TreatmentTargetScope.patient;
  }

  List<String> _bridgeValidationErrors() {
    if (bridgeUnits.isEmpty) return const [];
    final errors = <String>[];
    final toothNumbers = bridgeUnits.map((unit) => unit.toothFdi).toList();
    if (bridgeUnits.length < 2 ||
        toothNumbers.toSet().length != toothNumbers.length) {
      errors.add('bridgeUnits');
    }
    if (toothNumbers.any((fdi) => !isPermanentFdi(fdi))) {
      errors.add('bridgeUnits');
    }
    final hasPontic =
        bridgeUnits.any((unit) => unit.role == BridgeUnitRole.pontic);
    final hasSupport = bridgeUnits.any(
      (unit) =>
          unit.role == BridgeUnitRole.abutment ||
          unit.role == BridgeUnitRole.implantAbutment,
    );
    if (!hasPontic || !hasSupport) errors.add('bridgeUnits');
    return errors;
  }

  List<String> _removableValidationErrors() {
    final errors = <String>[];
    if (removableComponents.any(
      (component) =>
          !isPermanentFdi(component.toothFdi) ||
          !archContainsTooth(arch, component.toothFdi),
    )) {
      errors.add('removableComponents');
    }
    final identities = removableComponents
        .map((component) => '${component.toothFdi}:${component.role.name}')
        .toSet();
    if (identities.length != removableComponents.length) {
      errors.add('removableComponents');
    }
    return errors;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<T> _mapList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (value is! List) return <T>[];
    return value
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList();
  }
}
