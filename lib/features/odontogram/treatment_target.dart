enum TreatmentTargetScope {
  patient,
  tooth,
  bridge,
  removableProsthesis,
}

enum SurfaceSelectionMode {
  notApplicable,
  optional,
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

bool isUpperFdi(int fdi) => fdi ~/ 10 == 1 || fdi ~/ 10 == 2;

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
