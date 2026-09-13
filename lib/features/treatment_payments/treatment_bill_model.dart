import 'package:apexo/core/model.dart';

/// One explicitly confirmed treatment charge. Never synthesized from a
/// catalogue price or a migrated DentalWin historical snapshot.
class TreatmentBill extends Model {
  String patientID = '';
  String odontogramEventID = '';
  String treatmentNameSnapshot = '';
  double chargeAmount = 0;
  DateTime confirmedAt = DateTime.now();

  TreatmentBill.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID']?.toString() ?? patientID;
    odontogramEventID =
        json['odontogramEventID']?.toString() ?? odontogramEventID;
    treatmentNameSnapshot =
        json['treatmentNameSnapshot']?.toString() ?? treatmentNameSnapshot;
    title = treatmentNameSnapshot;
    chargeAmount = moneyValue(json['chargeAmount'], chargeAmount);
    confirmedAt = dateValue(json['confirmedAt']) ?? confirmedAt;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'patientID': patientID,
        'odontogramEventID': odontogramEventID,
        'treatmentNameSnapshot': treatmentNameSnapshot,
        'chargeAmount': chargeAmount,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      };

  @override
  TreatmentBill copy(bool blank) =>
      TreatmentBill.fromJson(blank ? <String, dynamic>{} : toJson());

  List<String> validationErrors() {
    final errors = <String>[];
    if (patientID.trim().isEmpty) errors.add('patientID');
    if (odontogramEventID.trim().isEmpty) errors.add('odontogramEventID');
    if (id != odontogramEventID) errors.add('id');
    if (treatmentNameSnapshot.trim().isEmpty) {
      errors.add('treatmentNameSnapshot');
    }
    if (!isValidMoney(chargeAmount, allowZero: true)) {
      errors.add('chargeAmount');
    }
    return errors;
  }
}

/// Every payment, fee correction, receipt change and void is a new row. This
/// is append-only so concurrent sync of different entries cannot lose money
/// records through Store.mergeConflict's whole-list LWW behavior.
enum TreatmentPaymentEntryKind {
  payment,
  amountCorrection,
  receiptCorrection,
  voidPayment,
  chargeCorrection,
}

class TreatmentPaymentEntry extends Model {
  String patientID = '';
  String odontogramEventID = '';
  String paymentID = '';
  TreatmentPaymentEntryKind kind = TreatmentPaymentEntryKind.payment;
  double? amount;
  bool? receipt;

  /// Monotonic within one client's current view of the treatment ledger.
  /// Distinct clients may tie while offline; occurredAt/id break those ties.
  int sequence = 0;
  DateTime occurredAt = DateTime.now();

  TreatmentPaymentEntry.fromJson(super.json) : super.fromJson();

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    patientID = json['patientID']?.toString() ?? patientID;
    odontogramEventID =
        json['odontogramEventID']?.toString() ?? odontogramEventID;
    paymentID = json['paymentID']?.toString() ?? paymentID;
    kind = TreatmentPaymentEntryKind.values.firstWhere(
      (candidate) => candidate.name == json['kind'],
      orElse: () => TreatmentPaymentEntryKind.payment,
    );
    amount = json['amount'] == null ? null : moneyValue(json['amount'], 0);
    receipt = json['receipt'] is bool ? json['receipt'] as bool : null;
    sequence = json['sequence'] is num
        ? (json['sequence'] as num).toInt()
        : int.tryParse('${json['sequence']}') ?? sequence;
    occurredAt = dateValue(json['occurredAt']) ?? occurredAt;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'patientID': patientID,
        'odontogramEventID': odontogramEventID,
        if (paymentID.isNotEmpty) 'paymentID': paymentID,
        'kind': kind.name,
        if (amount != null) 'amount': amount,
        if (receipt != null) 'receipt': receipt,
        'sequence': sequence,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
      };

  @override
  TreatmentPaymentEntry copy(bool blank) =>
      TreatmentPaymentEntry.fromJson(blank ? <String, dynamic>{} : toJson());

  List<String> validationErrors() {
    final errors = <String>[];
    if (patientID.trim().isEmpty) errors.add('patientID');
    if (odontogramEventID.trim().isEmpty) errors.add('odontogramEventID');
    if (sequence < 0) errors.add('sequence');
    if (kind == TreatmentPaymentEntryKind.payment) {
      if (paymentID.isNotEmpty) errors.add('paymentID');
    } else if (kind == TreatmentPaymentEntryKind.chargeCorrection) {
      if (paymentID.isNotEmpty) errors.add('paymentID');
    } else if (paymentID.trim().isEmpty) {
      errors.add('paymentID');
    }
    switch (kind) {
      case TreatmentPaymentEntryKind.payment:
      case TreatmentPaymentEntryKind.amountCorrection:
        if (amount == null || !isValidMoney(amount!)) errors.add('amount');
        if (kind == TreatmentPaymentEntryKind.payment && receipt == null) {
          errors.add('receipt');
        }
      case TreatmentPaymentEntryKind.chargeCorrection:
        if (amount == null || !isValidMoney(amount!, allowZero: true)) {
          errors.add('amount');
        }
      case TreatmentPaymentEntryKind.receiptCorrection:
        if (receipt == null) errors.add('receipt');
      case TreatmentPaymentEntryKind.voidPayment:
        break;
    }
    return errors;
  }
}

enum TreatmentPaymentRevisionKind { amount, receipt, voided }

/// Derived from immutable entries, for UI display. Not serialized separately.
class TreatmentPaymentRevision {
  final TreatmentPaymentRevisionKind kind;
  final DateTime at;
  final double? oldAmount;
  final double? newAmount;
  final bool? oldReceipt;
  final bool? newReceipt;

  const TreatmentPaymentRevision({
    required this.kind,
    required this.at,
    this.oldAmount,
    this.newAmount,
    this.oldReceipt,
    this.newReceipt,
  });
}

/// Effective payment after folding its append-only correction entries.
class TreatmentPayment {
  final String id;
  final double amount;
  final DateTime paidAt;
  final bool receipt;
  final DateTime? voidedAt;
  final List<TreatmentPaymentRevision> revisions;

  const TreatmentPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.receipt,
    this.voidedAt,
    this.revisions = const [],
  });

  bool get isActive => voidedAt == null;
  int get amountCents => (amount * 100).round();

  TreatmentPayment copyWith({
    double? amount,
    bool? receipt,
    DateTime? voidedAt,
    List<TreatmentPaymentRevision>? revisions,
  }) =>
      TreatmentPayment(
        id: id,
        amount: amount ?? this.amount,
        paidAt: paidAt,
        receipt: receipt ?? this.receipt,
        voidedAt: voidedAt ?? this.voidedAt,
        revisions: revisions ?? this.revisions,
      );
}

/// Current account derived from one confirmed charge and all ledger entries.
class TreatmentBillAccount {
  final TreatmentBill bill;
  final double chargeAmount;
  final List<TreatmentPayment> payments;

  const TreatmentBillAccount({
    required this.bill,
    required this.chargeAmount,
    required this.payments,
  });

  String get patientID => bill.patientID;
  String get odontogramEventID => bill.odontogramEventID;
  String get treatmentNameSnapshot => bill.treatmentNameSnapshot;
  DateTime get confirmedAt => bill.confirmedAt;
  int get chargeCents => (chargeAmount * 100).round();
  int get paidCents => payments
      .where((payment) => payment.isActive)
      .fold(0, (sum, payment) => sum + payment.amountCents);
  int get balanceCents => chargeCents - paidCents;
  double get paidAmount => paidCents / 100;
  double get balance => balanceCents / 100;
  bool get isFullyPaid => balanceCents == 0;

  /// Can occur if two offline clients each collect against the same balance.
  /// Never clamp this value silently; the UI must flag it for reconciliation.
  bool get isOverpaid => balanceCents < 0;
}

bool isValidMoney(double amount, {bool allowZero = false}) =>
    amount.isFinite &&
    amount >= 0 &&
    (allowZero || amount > 0) &&
    (amount * 100 - (amount * 100).round()).abs() < 0.000001;

double moneyValue(dynamic value, double fallback) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

DateTime? dateValue(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());
