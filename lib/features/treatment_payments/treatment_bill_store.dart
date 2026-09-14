import 'dart:convert';

import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:crypto/crypto.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;

import 'treatment_bill_model.dart';
import 'treatment_payment_entry_store.dart';

export 'treatment_bill_model.dart';
export 'treatment_payment_entry_store.dart';

const _storeName = 'treatment_bills';
const _legacyBillCollisionError =
    'A legacy treatment bill shares its odontogram event ID. '
    'Payment edits and bill sync are blocked until the record is reviewed.';

/// Stable PocketBase ID in a separate namespace from the event ID. Offline
/// clients derive the same bill ID for the same treatment.
String treatmentBillRecordID(String odontogramEventID) {
  if (odontogramEventID.trim().isEmpty) {
    throw ArgumentError.value(odontogramEventID, 'odontogramEventID');
  }
  final digest = sha256.convert(
    utf8.encode('apexo:treatment-bill:$odontogramEventID'),
  );
  var value = BigInt.zero;
  for (final byte in digest.bytes.take(9)) {
    value = (value << 8) | BigInt.from(byte);
  }
  final id = 'b${value.toRadixString(36).padLeft(14, '0')}';
  if (id == odontogramEventID) {
    throw StateError('Treatment bill ID collides with its event ID.');
  }
  return id;
}

/// Rejects legacy shared IDs at the actual write boundary. Store can push
/// directly after a local change, without going through synchronize().
class TreatmentBillSaveRemote extends SaveRemote {
  TreatmentBillSaveRemote({
    required super.pbInstance,
    super.onOnlineStatusChange,
  }) : super(storeName: _storeName);

  @override
  Future<bool> put(List<RowToWriteRemotely> data) async {
    for (final row in data) {
      final decoded = jsonDecode(row.data);
      if (decoded is! Map<String, dynamic> ||
          decoded['id'] != row.id ||
          decoded['odontogramEventID'] == null) {
        throw StateError('Invalid treatment bill row; remote write blocked.');
      }
      if (row.id == decoded['odontogramEventID']) {
        throw StateError(_legacyBillCollisionError);
      }
      try {
        final existing = await remoteRows.getOne(row.id, fields: 'store');
        if (existing.getStringValue('store') != _storeName) {
          throw StateError('Treatment bill ID belongs to another data store.');
        }
      } on ClientException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
    }
    return super.put(data);
  }
}

/// Confirmed per-treatment charges. The companion append-only entry store
/// holds every payment/change/void as its own synced document.
class TreatmentBills extends Store<TreatmentBill> {
  TreatmentBills()
      : super(
          modeling: TreatmentBill.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () =>
              networkActions.isSyncing(networkActions.isSyncing() + 1),
          onSyncEnd: () =>
              networkActions.isSyncing(networkActions.isSyncing() - 1),
        );

  List<TreatmentBill> forPatient(String patientID) => List.unmodifiable(
        present.values.where((bill) => bill.patientID == patientID).toList()
          ..sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt)),
      );

  TreatmentBill? forEvent(String odontogramEventID) {
    final matches = present.values
        .where((bill) => bill.odontogramEventID == odontogramEventID)
        .toList();
    if (matches.length > 1) {
      throw StateError('Multiple treatment bills refer to one event.');
    }
    return matches.isEmpty ? null : matches.single;
  }

  List<TreatmentBillAccount> accountsForPatient(String patientID) =>
      List.unmodifiable(
        forPatient(patientID)
            .map((bill) => accountForEvent(bill.odontogramEventID)!)
            .toList(),
      );

  List<TreatmentBillAccount> get allAccounts => List.unmodifiable(
        present.values
            .map((bill) => accountForEvent(bill.odontogramEventID)!)
            .toList()
          ..sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt)),
      );

  TreatmentBillAccount? accountForEvent(String odontogramEventID) {
    final bill = forEvent(odontogramEventID);
    if (bill == null) return null;
    final entries = treatmentPaymentEntries.forEvent(odontogramEventID);
    final payments = <String, TreatmentPayment>{};
    var chargeAmount = bill.chargeAmount;

    // First establish original payments; process their revisions separately
    // so a clock-skewed correction still has its parent payment to apply to.
    for (final entry in entries) {
      if (entry.kind != TreatmentPaymentEntryKind.payment) continue;
      payments[entry.id] = TreatmentPayment(
        id: entry.id,
        amount: entry.amount!,
        paidAt: entry.occurredAt,
        receipt: entry.receipt!,
      );
    }
    for (final entry in entries) {
      if (entry.kind == TreatmentPaymentEntryKind.chargeCorrection) {
        chargeAmount = entry.amount!;
        continue;
      }
      final payment = payments[entry.paymentID];
      if (payment == null || entry.kind == TreatmentPaymentEntryKind.payment) {
        continue;
      }
      switch (entry.kind) {
        case TreatmentPaymentEntryKind.payment:
        case TreatmentPaymentEntryKind.chargeCorrection:
          break;
        case TreatmentPaymentEntryKind.amountCorrection:
          if (!payment.isActive) break;
          payments[entry.paymentID] = payment.copyWith(
            amount: entry.amount!,
            revisions: [
              ...payment.revisions,
              TreatmentPaymentRevision(
                kind: TreatmentPaymentRevisionKind.amount,
                at: entry.occurredAt,
                oldAmount: payment.amount,
                newAmount: entry.amount,
              ),
            ],
          );
        case TreatmentPaymentEntryKind.receiptCorrection:
          if (!payment.isActive) break;
          payments[entry.paymentID] = payment.copyWith(
            receipt: entry.receipt!,
            revisions: [
              ...payment.revisions,
              TreatmentPaymentRevision(
                kind: TreatmentPaymentRevisionKind.receipt,
                at: entry.occurredAt,
                oldReceipt: payment.receipt,
                newReceipt: entry.receipt,
              ),
            ],
          );
        case TreatmentPaymentEntryKind.voidPayment:
          if (!payment.isActive) break;
          payments[entry.paymentID] = payment.copyWith(
            voidedAt: entry.occurredAt,
            revisions: [
              ...payment.revisions,
              TreatmentPaymentRevision(
                kind: TreatmentPaymentRevisionKind.voided,
                at: entry.occurredAt,
                oldAmount: payment.amount,
                newAmount: 0,
              ),
            ],
          );
      }
    }
    return TreatmentBillAccount(
      bill: bill,
      chargeAmount: chargeAmount,
      payments: List.unmodifiable(payments.values.toList()
        ..sort((a, b) => a.paidAt.compareTo(b.paidAt))),
    );
  }

  /// [amount] is explicitly confirmed, never inferred from the odontogram's
  /// priceSnapshot or from a migrated DentalWin record.
  TreatmentBillAccount confirmCharge({
    required String patientID,
    required String odontogramEventID,
    required String treatmentNameSnapshot,
    required double amount,
    DateTime? at,
  }) {
    final cents = _cents(amount, allowZero: true);
    if (patientID.trim().isEmpty ||
        odontogramEventID.trim().isEmpty ||
        treatmentNameSnapshot.trim().isEmpty) {
      throw ArgumentError('Patient, treatment event, and name are required.');
    }
    final existing = forEvent(odontogramEventID);
    if (existing != null && existing.patientID != patientID) {
      throw StateError('Treatment bill belongs to another patient.');
    }
    if (existing != null) _requireNonCollidingBill(existing);
    if (existing == null) {
      set(TreatmentBill.fromJson({
        'id': treatmentBillRecordID(odontogramEventID),
        'patientID': patientID,
        'odontogramEventID': odontogramEventID,
        'treatmentNameSnapshot': treatmentNameSnapshot.trim(),
        'chargeAmount': cents / 100,
        'confirmedAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
      }));
    } else {
      final account = accountForEvent(odontogramEventID)!;
      if (cents < account.paidCents) {
        throw StateError('Charge cannot be less than active payments.');
      }
      if (cents != account.chargeCents) {
        _appendEntry(
          account,
          kind: TreatmentPaymentEntryKind.chargeCorrection,
          amount: cents / 100,
          at: at,
        );
      }
    }
    return accountForEvent(odontogramEventID)!;
  }

  TreatmentBillAccount addPayment({
    required String odontogramEventID,
    required double amount,
    required bool receipt,
    DateTime? paidAt,
  }) {
    final account = _requiredAccount(odontogramEventID);
    final cents = _cents(amount);
    if (cents > account.balanceCents) {
      throw StateError('Payment exceeds remaining treatment balance.');
    }
    _appendEntry(
      account,
      kind: TreatmentPaymentEntryKind.payment,
      amount: cents / 100,
      receipt: receipt,
      at: paidAt,
    );
    return accountForEvent(odontogramEventID)!;
  }

  TreatmentBillAccount settle({
    required String odontogramEventID,
    required bool receipt,
    DateTime? paidAt,
  }) {
    final account = _requiredAccount(odontogramEventID);
    if (account.balanceCents <= 0) {
      throw StateError('Treatment has no remaining balance.');
    }
    return addPayment(
      odontogramEventID: odontogramEventID,
      amount: account.balanceCents / 100,
      receipt: receipt,
      paidAt: paidAt,
    );
  }

  TreatmentBillAccount correctPayment({
    required String odontogramEventID,
    required String paymentID,
    required double amount,
    DateTime? at,
  }) {
    final account = _requiredAccount(odontogramEventID);
    final payment = _activePayment(account, paymentID);
    final cents = _cents(amount);
    if (account.paidCents - payment.amountCents + cents > account.chargeCents) {
      throw StateError('Corrected payment exceeds treatment charge.');
    }
    if (cents != payment.amountCents) {
      _appendEntry(
        account,
        kind: TreatmentPaymentEntryKind.amountCorrection,
        paymentID: paymentID,
        amount: cents / 100,
        at: at,
      );
    }
    return accountForEvent(odontogramEventID)!;
  }

  TreatmentBillAccount setReceipt({
    required String odontogramEventID,
    required String paymentID,
    required bool receipt,
    DateTime? at,
  }) {
    final account = _requiredAccount(odontogramEventID);
    final payment = _activePayment(account, paymentID);
    if (payment.receipt != receipt) {
      _appendEntry(
        account,
        kind: TreatmentPaymentEntryKind.receiptCorrection,
        paymentID: paymentID,
        receipt: receipt,
        at: at,
      );
    }
    return accountForEvent(odontogramEventID)!;
  }

  TreatmentBillAccount voidPayment({
    required String odontogramEventID,
    required String paymentID,
    DateTime? at,
  }) {
    final account = _requiredAccount(odontogramEventID);
    _activePayment(account, paymentID);
    _appendEntry(
      account,
      kind: TreatmentPaymentEntryKind.voidPayment,
      paymentID: paymentID,
      at: at,
    );
    return accountForEvent(odontogramEventID)!;
  }

  TreatmentBillAccount _requiredAccount(String eventID) {
    final account = accountForEvent(eventID);
    if (account == null) {
      throw StateError('Confirm treatment charge before payment.');
    }
    _requireNonCollidingBill(account.bill);
    return account;
  }

  static void _requireNonCollidingBill(TreatmentBill bill) {
    if (bill.id == bill.odontogramEventID) {
      throw StateError(_legacyBillCollisionError);
    }
  }

  static TreatmentPayment _activePayment(
    TreatmentBillAccount account,
    String paymentID,
  ) {
    for (final payment in account.payments) {
      if (payment.id != paymentID) continue;
      if (!payment.isActive) {
        throw StateError('Voided payments cannot be changed.');
      }
      return payment;
    }
    throw StateError('Payment not found.');
  }

  void _appendEntry(
    TreatmentBillAccount account, {
    required TreatmentPaymentEntryKind kind,
    String paymentID = '',
    double? amount,
    bool? receipt,
    DateTime? at,
  }) {
    final prior = treatmentPaymentEntries.forEvent(account.odontogramEventID);
    final nextSequence = prior.isEmpty
        ? 1
        : prior.map((entry) => entry.sequence).reduce((a, b) => a > b ? a : b) +
            1;
    treatmentPaymentEntries.set(TreatmentPaymentEntry.fromJson({
      'patientID': account.patientID,
      'odontogramEventID': account.odontogramEventID,
      if (paymentID.isNotEmpty) 'paymentID': paymentID,
      'kind': kind.name,
      if (amount != null) 'amount': amount,
      if (receipt != null) 'receipt': receipt,
      'sequence': nextSequence,
      'occurredAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
    }));
  }

  static int _cents(double amount, {bool allowZero = false}) {
    if (!isValidMoney(amount, allowZero: allowZero)) {
      throw ArgumentError.value(amount, 'amount', 'Use cent precision.');
    }
    return (amount * 100).round();
  }

  @override
  void set(TreatmentBill item) {
    _requireNonCollidingBill(item);
    final errors = item.validationErrors();
    if (errors.isNotEmpty) {
      throw ArgumentError(
          'Invalid treatment bill fields: ${errors.join(', ')}');
    }
    if (has(item.id)) {
      throw StateError(
          'Original charge records are immutable; confirm a correction.');
    }
    if (forEvent(item.odontogramEventID) != null) {
      throw StateError('A charge already exists for this treatment event.');
    }
    super.set(item);
  }

  @override
  Future<List<SyncResult>> synchronize() {
    // A queued bill from the older build can overwrite an odontogram event
    // even if no new charge is entered. Never push such a row automatically.
    if (docs.values.any((bill) => bill.id == bill.odontogramEventID)) {
      return Future.value([
        SyncResult(exception: _legacyBillCollisionError),
      ]);
    }
    return super.synchronize();
  }

  @override
  void init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    login.activators[_storeName] = () async {
      await loaded;
      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();
      if (!launch.isDemo) {
        remote = TreatmentBillSaveRemote(
          pbInstance: login.pb!,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) network.isOnline(current);
          },
        );
      }
      return () async {
        loginCtrl.loadingIndicator('Synchronizing treatment bills');
        await synchronize();
        networkActions.syncCallbacks[_storeName] = synchronize;
        if (remote != null) {
          networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;
        }
        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }
}

final treatmentBills = TreatmentBills();
