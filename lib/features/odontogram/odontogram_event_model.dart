import 'package:apexo/core/model.dart';

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
  int? toothFdi;
  List<String> surfaces = [];
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

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID']?.toString() ?? patientID;
    toothFdi = _asNullableInt(json['toothFdi']);
    surfaces = List<String>.from(json['surfaces'] ?? const <String>[]);
    procedureID = json['procedureID']?.toString() ?? procedureID;
    procedureNameSnapshot = json['procedureNameSnapshot']?.toString() ?? title;
    title = procedureNameSnapshot;
    therapyGroupID = json['therapyGroupID']?.toString() ?? therapyGroupID;
    therapyGroupNameSnapshot = json['therapyGroupNameSnapshot']?.toString() ??
        therapyGroupNameSnapshot;
    priceSnapshot = _asNullableDouble(json['priceSnapshot']);
    eventKind = _enumValue(
      OdontogramEventKind.values,
      json['eventKind'],
      eventKind,
    );
    status = _enumValue(
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
    if (toothFdi != null) json['toothFdi'] = toothFdi;
    if (surfaces.isNotEmpty) json['surfaces'] = surfaces;
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
    if (toothFdi != null && !_isPermanentFdi(toothFdi!)) {
      errors.add('toothFdi');
    }
    if (surfaces.contains('wholeTooth') && surfaces.length > 1) {
      errors.add('surfaces');
    }
    return errors;
  }

  @override
  OdontogramEvent copy(bool blank) =>
      OdontogramEvent.fromJson(blank ? <String, dynamic>{} : toJson());

  static bool _isPermanentFdi(int fdi) {
    final quadrant = fdi ~/ 10;
    final position = fdi % 10;
    return quadrant >= 1 && quadrant <= 4 && position >= 1 && position <= 8;
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

  static T _enumValue<T extends Enum>(
    List<T> values,
    dynamic raw,
    T fallback,
  ) {
    return values.where((value) => value.name == raw).firstOrNull ?? fallback;
  }
}
