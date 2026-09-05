import 'package:apexo/core/model.dart';

enum ShoppingPriority { normal, soon, urgent }

ShoppingPriority _priorityFromJson(dynamic value) {
  final name = value?.toString();
  return ShoppingPriority.values.firstWhere(
    (priority) => priority.name == name,
    orElse: () => ShoppingPriority.normal,
  );
}

class ShoppingItem extends Model {
  bool isCategory = false;
  String categoryID = '';
  double displayOrder = 0;
  List<String> variants = [];
  String selectedVariant = '';
  bool needed = false;
  ShoppingPriority priority = ShoppingPriority.normal;
  String quantity = '';
  String notes = '';

  ShoppingItem.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    isCategory = json['isCategory'] == true;
    categoryID = json['categoryID']?.toString() ?? '';
    displayOrder = double.tryParse(json['displayOrder']?.toString() ?? '') ?? 0;
    variants = List<String>.from(json['variants'] ?? const <String>[])
        .map((variant) => variant.trim())
        .where((variant) => variant.isNotEmpty)
        .toList();
    selectedVariant = json['selectedVariant']?.toString().trim() ?? '';
    needed = json['needed'] == true;
    priority = _priorityFromJson(json['priority']);
    quantity = json['quantity']?.toString() ?? '';
    notes = json['notes']?.toString() ?? '';
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (isCategory) json['isCategory'] = true;
    if (categoryID.isNotEmpty) json['categoryID'] = categoryID;
    if (displayOrder != 0) json['displayOrder'] = displayOrder;
    if (variants.isNotEmpty) json['variants'] = variants;
    if (selectedVariant.isNotEmpty) {
      json['selectedVariant'] = selectedVariant;
    }
    if (needed) json['needed'] = true;
    if (priority != ShoppingPriority.normal) {
      json['priority'] = priority.name;
    }
    if (quantity.isNotEmpty) json['quantity'] = quantity;
    if (notes.isNotEmpty) json['notes'] = notes;
    return json;
  }

  @override
  ShoppingItem copy(bool blank) =>
      ShoppingItem.fromJson(blank ? <String, dynamic>{} : toJson());

  String get displayName =>
      selectedVariant.isEmpty ? title : '$title — $selectedVariant';
}
