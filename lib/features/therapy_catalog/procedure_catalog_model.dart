import 'package:apexo/core/model.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';

class ProcedureCatalogItem extends Model {
  String therapyGroupID = '';
  String therapyGroupSourceID = '';
  String sourceCode = '';
  double basePrice = 0;
  bool? toothRequired;
  bool? perToothPrice;
  int? durationMinutes;
  ProcedureHandlingMode? handlingMode;
  OdontogramOverlayKind? odontogramOverlay;
  TreatmentTargetScope? targetScope;
  SurfaceSelectionMode surfaceSelectionMode = SurfaceSelectionMode.optional;
  List<String> defaultSurfaces = [];
  bool hidden = false;
  bool? requiresLaboratory;
  Map<String, dynamic> migration = {};

  ProcedureCatalogItem.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    title = json['name']?.toString() ?? title;
    therapyGroupID = json['therapyGroupID']?.toString() ?? therapyGroupID;
    therapyGroupSourceID =
        json['therapyGroupSourceID']?.toString() ?? therapyGroupSourceID;
    sourceCode = json['sourceCode']?.toString() ?? sourceCode;
    basePrice = _asDouble(json['basePrice'], basePrice);
    toothRequired = _asNullableBool(json['toothRequired']);
    perToothPrice = _asNullableBool(json['perToothPrice']);
    durationMinutes = _asNullableInt(json['durationMinutes']);
    handlingMode = nullableEnumByName(
      ProcedureHandlingMode.values,
      json['handlingMode'],
    );
    odontogramOverlay = nullableEnumByName(
      OdontogramOverlayKind.values,
      json['odontogramOverlay'],
    );
    targetScope = nullableEnumByName(
      TreatmentTargetScope.values,
      json['targetScope'],
    );
    surfaceSelectionMode = enumByName(
      SurfaceSelectionMode.values,
      json['surfaceSelectionMode'],
      surfaceSelectionMode,
    );
    defaultSurfaces = List<String>.from(
      json['defaultSurfaces'] ?? const <String>[],
    );
    hidden = json['hidden'] == true;
    requiresLaboratory = _asNullableBool(json['requiresLaboratory']);
    migration = Map<String, dynamic>.from(json['migration'] ?? migration);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['name'] = title;
    if (therapyGroupID.isNotEmpty) json['therapyGroupID'] = therapyGroupID;
    if (therapyGroupSourceID.isNotEmpty) {
      json['therapyGroupSourceID'] = therapyGroupSourceID;
    }
    if (sourceCode.isNotEmpty) json['sourceCode'] = sourceCode;
    json['basePrice'] = basePrice;
    if (toothRequired != null) json['toothRequired'] = toothRequired;
    if (perToothPrice != null) json['perToothPrice'] = perToothPrice;
    if (durationMinutes != null) json['durationMinutes'] = durationMinutes;
    if (handlingMode != null) json['handlingMode'] = handlingMode!.name;
    if (odontogramOverlay != null) {
      json['odontogramOverlay'] = odontogramOverlay!.name;
    }
    if (targetScope != null) json['targetScope'] = targetScope!.name;
    json['surfaceSelectionMode'] = surfaceSelectionMode.name;
    if (defaultSurfaces.isNotEmpty) {
      json['defaultSurfaces'] = defaultSurfaces;
    }
    if (hidden) json['hidden'] = true;
    if (requiresLaboratory != null) {
      json['requiresLaboratory'] = requiresLaboratory;
    }
    if (migration.isNotEmpty) json['migration'] = migration;
    return json;
  }

  @override
  ProcedureCatalogItem copy(bool blank) =>
      ProcedureCatalogItem.fromJson(blank ? <String, dynamic>{} : toJson());

  TreatmentTargetScope get effectiveTargetScope {
    if (handlingMode != null) return handlingMode!.targetScope;
    if (targetScope != null) return targetScope!;
    if (toothRequired == false) return TreatmentTargetScope.patient;
    return TreatmentTargetScope.tooth;
  }

  /// Converts a catalogue choice into the legacy target fields as well. This
  /// keeps older clients/readers compatible while the new handling mode is the
  /// single source of truth for the current UI.
  void applyHandlingMode(ProcedureHandlingMode mode) {
    handlingMode = mode;
    targetScope = mode.targetScope;
    surfaceSelectionMode = mode.surfaceSelectionMode;
    if (mode == ProcedureHandlingMode.surfaceBased) {
      defaultSurfaces.remove('wholeTooth');
    } else {
      defaultSurfaces = [...mode.automaticSurfaces];
    }
    toothRequired = mode.targetScope != TreatmentTargetScope.patient;
  }

  /// Backward-compatible interpretation for records created before the single
  /// five-way setting existed. Catalogue-level inference is applied later when
  /// no explicit/legacy target information is present.
  ProcedureHandlingMode? get legacyHandlingMode {
    if (handlingMode != null) return handlingMode;
    if (targetScope == TreatmentTargetScope.bridge) {
      return ProcedureHandlingMode.bridge;
    }
    if (targetScope == TreatmentTargetScope.removableProsthesis) {
      return ProcedureHandlingMode.removableProsthesis;
    }
    if (targetScope == TreatmentTargetScope.patient) {
      return ProcedureHandlingMode.patientLevel;
    }
    if (targetScope == TreatmentTargetScope.tooth) {
      if (surfaceSelectionMode == SurfaceSelectionMode.automaticWholeTooth ||
          defaultSurfaces.contains('wholeTooth')) {
        return ProcedureHandlingMode.wholeTooth;
      }
      if (surfaceSelectionMode == SurfaceSelectionMode.notApplicable) {
        return ProcedureHandlingMode.wholeTooth;
      }
      return ProcedureHandlingMode.surfaceBased;
    }
    return null;
  }

  List<String> validationErrors() {
    final errors = <String>[];
    const validSurfaces = {
      'mesial',
      'distal',
      'facial',
      'oral',
      'occlusalIncisal',
      'wholeTooth',
    };
    if (defaultSurfaces.any((surface) => !validSurfaces.contains(surface))) {
      errors.add('defaultSurfaces');
    }
    if (defaultSurfaces.contains('wholeTooth') && defaultSurfaces.length > 1) {
      errors.add('defaultSurfaces');
    }
    if (surfaceSelectionMode == SurfaceSelectionMode.notApplicable &&
        defaultSurfaces.isNotEmpty) {
      errors.add('defaultSurfaces');
    }
    if (surfaceSelectionMode == SurfaceSelectionMode.automaticWholeTooth &&
        (defaultSurfaces.length != 1 ||
            defaultSurfaces.single != 'wholeTooth')) {
      errors.add('defaultSurfaces');
    }
    if (effectiveTargetScope != TreatmentTargetScope.tooth &&
        defaultSurfaces.isNotEmpty) {
      errors.add('defaultSurfaces');
    }
    return errors;
  }

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static bool? _asNullableBool(dynamic value) {
    if (value == null || value == '') return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (['true', '1', 'yes'].contains(normalized)) return true;
    if (['false', '0', 'no'].contains(normalized)) return false;
    return null;
  }
}
