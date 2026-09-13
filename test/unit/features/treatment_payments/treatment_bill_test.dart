import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eventID = 'treatment12345';
  setUp(() => treatmentPaymentEntries.observableMap.clear());

  TreatmentBillAccount billFor(TreatmentBills store, {double charge = 500}) =>
      store.confirmCharge(
        patientID: 'patient-1',
        odontogramEventID: eventID,
        treatmentNameSnapshot: 'Στεφάνη επί εμφυτεύματος',
        amount: charge,
        at: DateTime.utc(2026, 9, 12),
      );

  test('catalogue price alone does not create a confirmed charge', () {
    final store = TreatmentBills();
    expect(store.forPatient('patient-1'), isEmpty);
    expect(store.accountForEvent(eventID), isNull);
  });

  test('settlement then correction derives partial state and keeps both rows',
      () {
    final store = TreatmentBills();
    billFor(store);
    var account = store.settle(
      odontogramEventID: eventID,
      receipt: true,
      paidAt: DateTime.utc(2026, 9, 13),
    );
    expect(account.paidAmount, 500);
    expect(account.isFullyPaid, isTrue);
    final paymentID = account.payments.single.id;

    account = store.correctPayment(
      odontogramEventID: eventID,
      paymentID: paymentID,
      amount: 300,
      at: DateTime.utc(2026, 9, 14),
    );
    expect(account.paidAmount, 300);
    expect(account.balance, 200);
    expect(account.isFullyPaid, isFalse);
    expect(account.payments.single.revisions.single.kind,
        TreatmentPaymentRevisionKind.amount);
    expect(account.payments.single.revisions.single.oldAmount, 500);
    expect(account.payments.single.revisions.single.newAmount, 300);
    expect(treatmentPaymentEntries.forEvent(eventID), hasLength(2));
    expect(TreatmentBill.fromJson(account.bill.toJson()).toJson(),
        account.bill.toJson());
  });

  test('voided payment stays in audit rows but is excluded from income', () {
    final store = TreatmentBills();
    billFor(store);
    var account = store.addPayment(
      odontogramEventID: eventID,
      amount: 100,
      receipt: false,
    );
    final paymentID = account.payments.single.id;
    account = store.voidPayment(
      odontogramEventID: eventID,
      paymentID: paymentID,
      at: DateTime.utc(2026, 9, 14),
    );
    expect(account.payments, hasLength(1));
    expect(account.payments.single.isActive, isFalse);
    expect(account.paidAmount, 0);
    expect(account.balance, 500);
    expect(treatmentPaymentEntries.forEvent(eventID), hasLength(2));
    expect(
        () => store.correctPayment(
              odontogramEventID: eventID,
              paymentID: paymentID,
              amount: 50,
            ),
        throwsStateError);
  });

  test('receipt correction changes category without changing balance', () {
    final store = TreatmentBills();
    billFor(store);
    var account = store.addPayment(
      odontogramEventID: eventID,
      amount: 100,
      receipt: false,
    );
    account = store.setReceipt(
      odontogramEventID: eventID,
      paymentID: account.payments.single.id,
      receipt: true,
    );
    expect(account.payments.single.receipt, isTrue);
    expect(account.payments.single.revisions.single.kind,
        TreatmentPaymentRevisionKind.receipt);
    expect(account.paidAmount, 100);
    expect(account.balance, 400);
  });

  test('never overpays and fee edits cannot undercut active payments', () {
    final store = TreatmentBills();
    billFor(store);
    var account = store.addPayment(
      odontogramEventID: eventID,
      amount: 300,
      receipt: false,
    );
    expect(
        () => store.addPayment(
              odontogramEventID: eventID,
              amount: 201,
              receipt: false,
            ),
        throwsStateError);
    expect(
        () => store.correctPayment(
              odontogramEventID: eventID,
              paymentID: account.payments.single.id,
              amount: 501,
            ),
        throwsStateError);
    expect(() => billFor(store, charge: 299), throwsStateError);
    expect(
        () => store.addPayment(
              odontogramEventID: eventID,
              amount: 0.001,
              receipt: false,
            ),
        throwsArgumentError);
    account = billFor(store, charge: 450);
    expect(account.chargeAmount, 450);
    expect(account.bill.chargeAmount, 500); // original confirmation retained
    expect(account.balance, 150);
    expect(treatmentPaymentEntries.forEvent(eventID).last.kind,
        TreatmentPaymentEntryKind.chargeCorrection);
  });

  test('different payments are separate immutable rows', () {
    final store = TreatmentBills();
    billFor(store);
    store.addPayment(
      odontogramEventID: eventID,
      amount: 10,
      receipt: true,
    );
    store.addPayment(
      odontogramEventID: eventID,
      amount: 15,
      receipt: false,
    );
    final entries = treatmentPaymentEntries.forEvent(eventID);
    expect(entries, hasLength(2));
    expect(entries.first.id, isNot(entries.last.id));
    expect(() => treatmentPaymentEntries.set(entries.first), throwsStateError);
  });

  test('rapid corrections with equal timestamps preserve causal order', () {
    final store = TreatmentBills();
    billFor(store);
    final sameInstant = DateTime.utc(2026, 9, 12, 12);
    var account = store.addPayment(
      odontogramEventID: eventID,
      amount: 500,
      receipt: false,
      paidAt: sameInstant,
    );
    final paymentID = account.payments.single.id;
    account = store.correctPayment(
      odontogramEventID: eventID,
      paymentID: paymentID,
      amount: 300,
      at: sameInstant,
    );
    account = store.correctPayment(
      odontogramEventID: eventID,
      paymentID: paymentID,
      amount: 200,
      at: sameInstant,
    );
    expect(account.paidAmount, 200);
    expect(account.balance, 300);
    expect(
        account.payments.single.revisions.map((revision) => revision.oldAmount),
        [500, 300]);
    expect(
        account.payments.single.revisions.map((revision) => revision.newAmount),
        [300, 200]);
    expect(
        treatmentPaymentEntries
            .forEvent(eventID)
            .map((entry) => entry.sequence),
        [1, 2, 3]);
  });

  test('two offline payment rows both survive and overpayment stays visible',
      () {
    final store = TreatmentBills();
    billFor(store, charge: 100);
    // Two devices each saw a €100 balance before either row was synced.
    for (final entryID in ['offlinepay00001', 'offlinepay00002']) {
      treatmentPaymentEntries.set(TreatmentPaymentEntry.fromJson({
        'id': entryID,
        'patientID': 'patient-1',
        'odontogramEventID': eventID,
        'kind': TreatmentPaymentEntryKind.payment.name,
        'amount': 100,
        'receipt': false,
        'occurredAt': DateTime.utc(2026, 9, 12).toIso8601String(),
      }));
    }
    final account = store.accountForEvent(eventID)!;
    expect(account.payments, hasLength(2));
    expect(account.paidAmount, 200);
    expect(account.balance, -100);
    expect(account.isOverpaid, isTrue);
    expect(account.isFullyPaid, isFalse);
  });
}
