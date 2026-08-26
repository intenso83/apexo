import 'package:apexo/core/model.dart';

class TherapyGroup extends Model {
  int displayOrder = 0;
  int colorValue = 0xFF0F8B8D;
  bool hidden = false;
  String sourceID = '';
  Map<String, dynamic> migration = {};

  TherapyGroup.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    title = json['name']?.toString() ?? title;
    displayOrder = _asInt(json['displayOrder'] ?? json['order'], displayOrder);
    colorValue = _asInt(json['colorValue'], colorValue);
    hidden = json['hidden'] == true;
    sourceID = json['sourceID']?.toString() ?? sourceID;
    migration = Map<String, dynamic>.from(json['migration'] ?? migration);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['name'] = title;
    json['displayOrder'] = displayOrder;
    json['colorValue'] = colorValue;
    if (hidden) json['hidden'] = true;
    if (sourceID.isNotEmpty) json['sourceID'] = sourceID;
    if (migration.isNotEmpty) json['migration'] = migration;
    return json;
  }

  @override
  TherapyGroup copy(bool blank) =>
      TherapyGroup.fromJson(blank ? <String, dynamic>{} : toJson());

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
