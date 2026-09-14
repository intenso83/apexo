import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/treatment_payments/patient_treatment_payments.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  const patientID = 'patient00000001';
  const eventID = 'paymentevent001';

  testWidgets('a completed treatment is not charged until confirmed',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addCompletedTreatment(patientID: patientID, eventID: eventID);

    await _pumpPayments(tester, patientID);

    expect(treatmentBills.accountsForPatient(patientID), isEmpty);
    expect(find.byKey(const Key('treatment-payment-confirm-charge')),
        findsOneWidget);
    expect(find.byKey(const Key('treatment-payment-settle')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('treatment-payment-charge-input')),
      '500.00',
    );
    await tester.tap(find.byKey(const Key('treatment-payment-confirm-charge')));
    await tester.pumpAndSettle();

    final account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.odontogramEventID, eventID);
    expect(account.chargeAmount, 500);
    expect(account.paidAmount, 0);
    expect(account.balance, 500);
    expect(find.byKey(const Key('treatment-payment-settle')), findsOneWidget);
  });

  testWidgets('full payment can be corrected, marked Rec, and voided',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addCompletedTreatment(patientID: patientID, eventID: eventID);

    await _pumpPayments(tester, patientID);
    await tester.tap(find.byKey(const Key('treatment-payment-confirm-charge')));
    await tester.pumpAndSettle();

    // The receipt choice belongs to the payment, not the treatment charge.
    await tester.tap(find.byKey(const Key('treatment-payment-new-rec')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treatment-payment-settle')));
    await tester.pumpAndSettle();

    var account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.paidAmount, 500);
    expect(account.balance, 0);
    expect(account.isFullyPaid, isTrue);
    expect(account.payments, hasLength(1));
    expect(account.payments.single.receipt, isTrue);
    final paymentID = account.payments.single.id;
    expect(find.byKey(const Key('treatment-payment-settle')), findsNothing);

    await tester.tap(find.byKey(Key('treatment-payment-edit-$paymentID')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('treatment-payment-correction-input')),
      '300.00',
    );
    await tester.tap(
      find.byKey(const Key('treatment-payment-save-correction')),
    );
    await tester.pumpAndSettle();

    account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.payments.single.id, paymentID);
    expect(account.payments.single.amount, 300);
    expect(account.payments.single.revisions, isNotEmpty);
    expect(account.paidAmount, 300);
    expect(account.balance, 200);
    expect(account.isFullyPaid, isFalse);
    expect(find.byKey(const Key('treatment-payment-settle')), findsOneWidget);

    await tester.tap(find.byKey(Key('treatment-payment-rec-$paymentID')));
    await tester.pumpAndSettle();
    account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.payments.single.receipt, isFalse);
    expect(account.paidAmount, 300);

    await tester.tap(find.byKey(Key('treatment-payment-edit-$paymentID')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treatment-payment-void')));
    await tester.pumpAndSettle();
    final confirmation = find.byType(ContentDialog);
    expect(confirmation, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: confirmation,
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.payments, hasLength(1));
    expect(account.payments.single.isActive, isFalse);
    expect(account.paidAmount, 0);
    expect(account.balance, 500);
    expect(account.isFullyPaid, isFalse);
    expect(treatmentPaymentEntries.forEvent(eventID), hasLength(4));
  });

  testWidgets('a mistaken confirmed charge can be corrected in the panel',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addCompletedTreatment(patientID: patientID, eventID: eventID);

    await _pumpPayments(tester, patientID);
    await tester.tap(find.byKey(const Key('treatment-payment-confirm-charge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treatment-payment-edit-charge')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('treatment-payment-charge-correction-input')),
      '450.00',
    );
    await tester.tap(
      find.byKey(const Key('treatment-payment-save-charge-correction')),
    );
    await tester.pumpAndSettle();

    final account = treatmentBills.accountsForPatient(patientID).single;
    expect(account.chargeAmount, 450);
    expect(account.balance, 450);
    expect(treatmentPaymentEntries.forEvent(eventID), hasLength(1));
  });

  testWidgets('legacy shared-ID bill shows amounts and history read-only',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addCompletedTreatment(patientID: patientID, eventID: eventID);
    // Model a bill already saved by the older build. The repaired store
    // correctly refuses to create a new one with this ID.
    treatmentBills.observableMap.set(TreatmentBill.fromJson({
      'id': eventID,
      'patientID': patientID,
      'odontogramEventID': eventID,
      'treatmentNameSnapshot': 'Στεφάνη επί εμφυτεύματος',
      'chargeAmount': 500,
    }));
    treatmentPaymentEntries.set(TreatmentPaymentEntry.fromJson({
      'id': 'legacypayment01',
      'patientID': patientID,
      'odontogramEventID': eventID,
      'kind': 'payment',
      'amount': 100,
      'receipt': true,
      'sequence': 1,
    }));

    await _pumpPayments(tester, patientID);

    expect(find.byKey(const Key('treatment-payment-legacy-warning')),
        findsOneWidget);
    expect(find.textContaining('500.00'), findsWidgets);
    expect(find.textContaining('100.00'), findsWidgets);
    expect(find.textContaining('400.00'), findsWidgets);
    expect(
        tester
            .widget<Button>(
              find.byKey(const Key('treatment-payment-edit-charge')),
            )
            .onPressed,
        isNull);
    expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('treatment-payment-settle')),
            )
            .onPressed,
        isNull);
    expect(
        tester
            .widget<Button>(
              find.byKey(const Key('treatment-payment-add-partial')),
            )
            .onPressed,
        isNull);
    expect(
        tester
            .widget<Checkbox>(
              find.byKey(const Key('treatment-payment-rec-legacypayment01')),
            )
            .onChanged,
        isNull);
    expect(
        tester
            .widget<Button>(
              find.byKey(const Key('treatment-payment-edit-legacypayment01')),
            )
            .onPressed,
        isNull);
    expect(treatmentPaymentEntries.forEvent(eventID), hasLength(1));
  });

  testWidgets('a legacy bill for another patient blocks new charges globally',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addCompletedTreatment(patientID: patientID, eventID: eventID);
    treatmentBills.observableMap.set(TreatmentBill.fromJson({
      'id': 'otherevent00001',
      'patientID': 'patient00000002',
      'odontogramEventID': 'otherevent00001',
      'treatmentNameSnapshot': 'Older charge',
      'chargeAmount': 50,
    }));

    await _pumpPayments(tester, patientID);

    expect(find.byKey(const Key('treatment-payment-legacy-warning')),
        findsOneWidget);
    expect(
        tester
            .widget<TextBox>(
              find.byKey(const Key('treatment-payment-charge-input')),
            )
            .enabled,
        isFalse);
    expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('treatment-payment-confirm-charge')),
            )
            .onPressed,
        isNull);
    expect(treatmentBills.accountsForPatient(patientID), isEmpty);
  });
}

void _prepareDemo() {
  launch.enterLocalDemo();
  odontogramEvents.observableMap.clear();
  treatmentBills.observableMap.clear();
  treatmentPaymentEntries.observableMap.clear();
}

void _clearDemo() {
  odontogramEvents.observableMap.clear();
  treatmentBills.observableMap.clear();
  treatmentPaymentEntries.observableMap.clear();
  launch.exitLocalDemo();
}

void _addCompletedTreatment({
  required String patientID,
  required String eventID,
}) {
  odontogramEvents.set(OdontogramEvent.fromJson({
    'id': eventID,
    'patientID': patientID,
    'targetScope': 'tooth',
    'toothFdi': 21,
    'procedureID': 'procedurecrown1',
    'procedureNameSnapshot': 'Στεφάνη επί εμφυτεύματος',
    'eventKind': 'treatment',
    'status': 'completed',
    'priceSnapshot': 500,
  }));
}

Future<void> _pumpPayments(WidgetTester tester, String patientID) async {
  await tester.binding.setSurfaceSize(const Size(1300, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpApexoApp(
    tester,
    ScaffoldPage(
      content: SingleChildScrollView(
        child: PatientTreatmentPayments(patientID: patientID),
      ),
    ),
  );
}
