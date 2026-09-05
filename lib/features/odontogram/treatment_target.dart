enum TreatmentTargetScope {
  patient,
  tooth,
  bridge,
  removableProsthesis,
}

/// The daily-entry workflow that Apexo opens after a procedure is selected.
///
/// This is deliberately stored on each procedure, rather than inferred from
/// its therapy group. A single group can therefore contain, for example, both
/// crowns and bridges without asking the clinician for an extra target choice.
enum ProcedureHandlingMode {
  surfaceBased,
  wholeTooth,
  bridge,
  removableProsthesis,
  patientLevel,
}

enum SurfaceSelectionMode {
  notApplicable,
  optional,
  automaticWholeTooth,
}

extension ProcedureHandlingModeRules on ProcedureHandlingMode {
  TreatmentTargetScope get targetScope => switch (this) {
        ProcedureHandlingMode.surfaceBased ||
        ProcedureHandlingMode.wholeTooth =>
          TreatmentTargetScope.tooth,
        ProcedureHandlingMode.bridge => TreatmentTargetScope.bridge,
        ProcedureHandlingMode.removableProsthesis =>
          TreatmentTargetScope.removableProsthesis,
        ProcedureHandlingMode.patientLevel => TreatmentTargetScope.patient,
      };

  SurfaceSelectionMode get surfaceSelectionMode => switch (this) {
        ProcedureHandlingMode.surfaceBased => SurfaceSelectionMode.optional,
        ProcedureHandlingMode.wholeTooth =>
          SurfaceSelectionMode.automaticWholeTooth,
        ProcedureHandlingMode.bridge ||
        ProcedureHandlingMode.removableProsthesis ||
        ProcedureHandlingMode.patientLevel =>
          SurfaceSelectionMode.notApplicable,
      };

  List<String> get automaticSurfaces => switch (this) {
        ProcedureHandlingMode.wholeTooth => const ['wholeTooth'],
        _ => const [],
      };
}

enum DentalArch {
  unspecified,
  upper,
  lower,
  both,
}

enum BridgeUnitRole {
  abutment,
  pontic,
  implantAbutment,
}

enum RemovableComponentRole {
  replacedTooth,
  clasp,
  rest,
  attachment,
  implantSupport,
}

class BridgeUnit {
  const BridgeUnit({required this.toothFdi, required this.role});

  final int toothFdi;
  final BridgeUnitRole role;

  factory BridgeUnit.fromJson(Map<String, dynamic> json) {
    return BridgeUnit(
      toothFdi: _asInt(json['toothFdi']),
      role: enumByName(
        BridgeUnitRole.values,
        json['role'],
        BridgeUnitRole.abutment,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'toothFdi': toothFdi,
        'role': role.name,
      };
}

class RemovableComponent {
  const RemovableComponent({required this.toothFdi, required this.role});

  final int toothFdi;
  final RemovableComponentRole role;

  factory RemovableComponent.fromJson(Map<String, dynamic> json) {
    return RemovableComponent(
      toothFdi: _asInt(json['toothFdi']),
      role: enumByName(
        RemovableComponentRole.values,
        json['role'],
        RemovableComponentRole.replacedTooth,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'toothFdi': toothFdi,
        'role': role.name,
      };
}

T enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

T? nullableEnumByName<T extends Enum>(List<T> values, dynamic raw) {
  if (raw == null || raw == '') return null;
  final name = raw.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool isPermanentFdi(int fdi) {
  final quadrant = fdi ~/ 10;
  final position = fdi % 10;
  return quadrant >= 1 && quadrant <= 4 && position >= 1 && position <= 8;
}

bool isPrimaryFdi(int fdi) {
  final quadrant = fdi ~/ 10;
  final position = fdi % 10;
  return quadrant >= 5 && quadrant <= 8 && position >= 1 && position <= 5;
}

bool isValidFdi(int fdi) => isPermanentFdi(fdi) || isPrimaryFdi(fdi);

bool isUpperFdi(int fdi) =>
    fdi ~/ 10 == 1 || fdi ~/ 10 == 2 || fdi ~/ 10 == 5 || fdi ~/ 10 == 6;

bool archContainsTooth(DentalArch arch, int fdi) {
  return switch (arch) {
    DentalArch.unspecified || DentalArch.both => true,
    DentalArch.upper => isUpperFdi(fdi),
    DentalArch.lower => !isUpperFdi(fdi),
  };
}

int _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
