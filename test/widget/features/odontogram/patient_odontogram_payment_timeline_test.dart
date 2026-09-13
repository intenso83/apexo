import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/patient_odontogram.dart';
import 'package:apexo/features/treatment_payments/treatment_bill_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  const patientID = 'timeline-patient-1';
  const billedEventID = 'timeline-billed-1';
  const unchargedEventID = 'timeline-uncharged-1';
  const importedEventID = 'timeline-imported-1';

  testWidgets('treatment history shows confirmed cost, paid, and balance',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addTreatment(
      patientID: patientID,
      eventID: billedEventID,
      name: 'Composite restoration',
      referencePrice: 900,
    );
    treatmentBills.confirmCharge(
      patientID: patientID,
      odontogramEventID: billedEventID,
      treatmentNameSnapshot: 'Composite restoration',
      amount: 120,
    );
    treatmentBills.addPayment(
      odontogramEventID: billedEventID,
      amount: 40,
      receipt: false,
    );

    await _pumpOdontogram(tester, patientID);

    final payment = find.byKey(const Key('odontogram-payment-$billedEventID'));
    expect(payment, findsOneWidget);
    var summary = _visibleText(tester, payment);
    expect(summary, contains('120.00'));
    expect(summary, contains('40.00'));
    expect(summary, contains('80.00'));
    expect(summary, contains(txt('paid')));
    expect(summary, contains(txt('underpaid')));
    expect(summary, isNot(contains('900.00')));
    expect(tester.getSize(payment).height, lessThan(64));

    treatmentBills.settle(odontogramEventID: billedEventID, receipt: true);
    await tester.pumpAndSettle();

    summary = _visibleText(tester, payment);
    expect(summary, contains('120.00'));
    expect(summary, contains(txt('paid')));
    expect(summary, contains(txt('fullyPaid')));
    expect(summary, isNot(contains('80.00')));
  });

  testWidgets('a reference price is not treated as an unpaid charge',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addTreatment(
      patientID: patientID,
      eventID: unchargedEventID,
      name: 'Uncharged implant crown',
      referencePrice: 500,
    );

    await _pumpOdontogram(tester, patientID);

    final payment =
        find.byKey(const Key('odontogram-payment-$unchargedEventID'));
    expect(payment, findsOneWidget);
    final summary = _visibleText(tester, payment);
    expect(summary, contains(txt('treatmentPaymentUncharged')));
    expect(summary, isNot(contains('500.00')));
    expect(summary, isNot(contains(txt('underpaid'))));
    expect(summary, isNot(contains(txt('fullyPaid'))));
  });

  testWidgets('imported DentalWin history has no payment strip without a bill',
      (tester) async {
    _prepareDemo();
    addTearDown(_clearDemo);
    _addTreatment(
      patientID: patientID,
      eventID: importedEventID,
      name: 'Imported bridge treatment',
      referencePrice: 700,
      treatmentHistoryID: 'dentalwin-history-1',
    );

    await _pumpOdontogram(tester, patientID);

    expect(find.text('Imported bridge treatment'), findsWidgets);
    expect(find.byKey(const Key('odontogram-payment-$importedEventID')),
        findsNothing);
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

void _addTreatment({
  required String patientID,
  required String eventID,
  required String name,
  required double referencePrice,
  String treatmentHistoryID = '',
}) {
  odontogramEvents.set(OdontogramEvent.fromJson({
    'id': eventID,
    'patientID': patientID,
    'targetScope': 'tooth',
    'toothFdi': 11,
    'surfaces': ['mesial'],
    'procedureID': 'timeline-procedure-1',
    'procedureNameSnapshot': name,
    'eventKind': 'treatment',
    'status': 'completed',
    'priceSnapshot': referencePrice,
    if (treatmentHistoryID.isNotEmpty) 'treatmentHistoryID': treatmentHistoryID,
    if (treatmentHistoryID.isNotEmpty) 'migration': {'source': 'dentalwin'},
  }));
}

Future<void> _pumpOdontogram(WidgetTester tester, String patientID) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpApexoApp(
    tester,
    SingleChildScrollView(
      child: SizedBox(
        width: 1200,
        child: PatientOdontogram(patientID: patientID),
      ),
    ),
  );
}

String _visibleText(WidgetTester tester, Finder subtree) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: subtree, matching: find.byType(Text)),
  );
  return texts
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join(' ');
}
