import 'package:apexo/core/model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/constants.dart';
import 'package:apexo/utils/imgs.dart';

class Expense extends Model {
  @override
  bool get locked {
    return login.perm(Perm.expenses).none;
  }

  bool get isOrder {
    return !isSupplier && !isCatalogueItem;
  }

  double get duePayments {
    final items = expenses.present.values.toList();
    double amount = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.supplierId != id) continue;
      if (item.processed) continue;
      amount = amount + (item.cost - item.paidAmount);
    }
    return amount;
  }

  String get fromSupplierName {
    return expenses.get(supplierId)?.supplierName ?? txt("unidentified");
  }

  @override
  String get title {
    if (isCatalogueItem) return "${txt("items")}: $catalogueItemName";
    return "${isSupplier ? txt("supplier") : txt("order")}: ${isSupplier ? supplierName : fromSupplierName}";
  }

  List<String> get viewableImgs {
    return photos.where((name) => isAnImageName(name)).toList();
  }

  // id: id of the expense item (inherited from Model)
  // title: title of the expense item (inherited from Model, useless)

  /* 1 */ bool isSupplier = false;
  /* 2 */ String supplierName = "";

  // Laboratories are suppliers too, so their invoices and prosthetic price
  // lists stay connected to one partner record.
  bool isLaboratory = false;
  String supplierContactName = "";
  String supplierPhone = "";
  String supplierMobile = "";
  String supplierEmail = "";
  String supplierAddress = "";
  Map<String, double> laboratoryProcedurePrices = {};

  // Reusable expense catalogue entries share the expense permission and sync
  // boundary. Existing free-text items on older orders remain supported.
  bool isCatalogueItem = false;
  String catalogueItemName = "";

  // when its an order
  /* 3 */ String supplierId = "";
  /* 4 */ DateTime date = DateTime.now();
  /* 5 */ List<String> items = [];
  /* 6 */ double cost = 0;
  /* 7 */ double paidAmount = 0;
  /* 8 */ bool processed = false;
  /* 9 */ List<String> photos = [];
  /* 10 */ String notes = "";

  Expense.fromJson(super.json) : super.fromJson();

  @override
  Expense copy(bool blank) {
    return Expense.fromJson(blank ? {} : toJson());
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    /* 1 */ isSupplier = json['isSupplier'] ?? isSupplier;
    /* 2 */ supplierName = json['supplierName'] ?? supplierName;
    isLaboratory = json['isLaboratory'] == true;
    supplierContactName = json['supplierContactName']?.toString() ?? '';
    supplierPhone = json['supplierPhone']?.toString() ?? '';
    supplierMobile = json['supplierMobile']?.toString() ?? '';
    supplierEmail = json['supplierEmail']?.toString() ?? '';
    supplierAddress = json['supplierAddress']?.toString() ?? '';
    laboratoryProcedurePrices = Map<String, double>.fromEntries(
      Map<String, dynamic>.from(
        json['laboratoryProcedurePrices'] ?? const <String, dynamic>{},
      ).entries.map(
            (entry) => MapEntry(
              entry.key,
              double.tryParse(entry.value.toString()) ?? 0,
            ),
          ),
    );
    isCatalogueItem = json['isCatalogueItem'] == true;
    catalogueItemName = json['catalogueItemName']?.toString() ?? '';

    /* 3 */ supplierId = json['supplierId'] ?? supplierId;
    /* 4 */ date = json["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch(json["date"] > 99999999
            ? json["date"]
            : json["date"] * 60 * 60 * 1000)
        : date;
    /* 5 */ items = List<String>.from(json["items"] ?? items);
    /* 6 */ cost = double.parse((json["cost"] ?? cost).toString());
    /* 7 */ paidAmount =
        double.parse((json["paidAmount"] ?? paidAmount).toString());
    /* 8 */ processed = json['processed'] ?? processed;
    /* 9 */ photos = List<String>.from(json["photos"] ?? photos);
    /* 10 */ notes = json["notes"] ?? notes;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Expense.fromJson({});
    /* 1 */ if (isSupplier != d.isSupplier) json['isSupplier'] = isSupplier;
    /* 2 */ if (supplierName != d.supplierName) {
      json['supplierName'] = supplierName;
    }
    if (isLaboratory) json['isLaboratory'] = true;
    if (supplierContactName.isNotEmpty) {
      json['supplierContactName'] = supplierContactName;
    }
    if (supplierPhone.isNotEmpty) json['supplierPhone'] = supplierPhone;
    if (supplierMobile.isNotEmpty) json['supplierMobile'] = supplierMobile;
    if (supplierEmail.isNotEmpty) json['supplierEmail'] = supplierEmail;
    if (supplierAddress.isNotEmpty) json['supplierAddress'] = supplierAddress;
    if (laboratoryProcedurePrices.isNotEmpty) {
      json['laboratoryProcedurePrices'] = laboratoryProcedurePrices;
    }
    if (isCatalogueItem) json['isCatalogueItem'] = true;
    if (catalogueItemName.isNotEmpty) {
      json['catalogueItemName'] = catalogueItemName;
    }

    /* 3 */ if (supplierId != d.supplierId) json['supplierId'] = supplierId;
    /* 4 */ json['date'] = date.millisecondsSinceEpoch;
    /* 5 */ if (items.isNotEmpty) json['items'] = items;
    /* 6 */ if (cost != d.cost) json['cost'] = cost;
    /* 7 */ if (paidAmount != d.paidAmount) json['paidAmount'] = paidAmount;
    /* 8 */ if (processed != d.processed) json['processed'] = processed;
    /* 9 */ if (photos.isNotEmpty) json['photos'] = photos;
    /* 10 */ if (notes != d.notes) json['notes'] = notes;

    return json;
  }
}
