import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_screen.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/features/treatment_history/treatment_history_model.dart';
import 'package:apexo/features/treatment_history/treatment_history_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/model_factory.dart';
import '../../../helpers/pump_app.dart';

void main() {
  const implantsID = 'group-implants';
  const surgeryID = 'group-surgery';
  const paltopID = 'procedure-paltop';
  const otherImplantID = 'procedure-other-implant';
  const extractionID = 'procedure-extraction';

  const nativePaltopPatientID = 'patient-native-paltop';
  const nativeOtherPatientID = 'patient-native-other';
  const nativeSurgeryPatientID = 'patient-native-surgery';
  const importedPaltopPatientID = 'patient-imported-paltop';

  setUp(() {
    launch.enterLocalDemo();
    patients.observableMap.clear();
    appointments.observableMap.clear();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();
    treatmentHistory.observableMap.clear();
    therapyGroups.debugSetCanonicalAliases(const {});
    procedureCatalog.debugSetCanonicalAliases(const {});

    patients.setAll([
      _testPatient(id: nativePaltopPatientID, name: 'Native Paltop'),
      _testPatient(id: nativeOtherPatientID, name: 'Native Other Implant'),
      _testPatient(id: nativeSurgeryPatientID, name: 'Native Surgery'),
      _testPatient(id: importedPaltopPatientID, name: 'Imported Paltop'),
    ]);
    therapyGroups.setAll([
      TherapyGroup.fromJson({
        'id': implantsID,
        'name': 'Εμφυτεύματα',
        'displayOrder': 1,
      }),
      TherapyGroup.fromJson({
        'id': surgeryID,
        'name': 'Χειρουργική',
        'displayOrder': 2,
      }),
    ]);
    procedureCatalog.setAll([
      ProcedureCatalogItem.fromJson({
        'id': paltopID,
        'name': 'Εμφύτευμα Paltop',
        'therapyGroupID': implantsID,
        'sourceCode': 'PALTOP-001',
      }),
      ProcedureCatalogItem.fromJson({
        'id': otherImplantID,
        'name': 'Εμφύτευμα Άλλο',
        'therapyGroupID': implantsID,
        'sourceCode': 'IMPLANT-002',
      }),
      ProcedureCatalogItem.fromJson({
        'id': extractionID,
        'name': 'Εξαγωγή φρονιμίτη',
        'therapyGroupID': surgeryID,
        'sourceCode': 'SURGERY-001',
      }),
    ]);
    odontogramEvents.setAll([
      _event('event-paltop', nativePaltopPatientID, paltopID, implantsID,
          'Εμφύτευμα Paltop', 'Εμφυτεύματα'),
      _event('event-other', nativeOtherPatientID, otherImplantID, implantsID,
          'Εμφύτευμα Άλλο', 'Εμφυτεύματα'),
      _event('event-surgery', nativeSurgeryPatientID, extractionID, surgeryID,
          'Εξαγωγή φρονιμίτη', 'Χειρουργική'),
    ]);
    // This DentalWin row deliberately has no odontogram projection. The
    // patient-list filter must still find it through canonical history.
    treatmentHistory.setAll([
      TreatmentHistoryEntry.fromJson({
        'id': 'history-imported-paltop',
        'patientID': importedPaltopPatientID,
        'treatmentName': 'Εμφύτευμα Paltop',
        'therapyGroup': 'Εμφυτεύματα',
        'sourceCatalogCode': 'PALTOP-001',
        'catalogLinkMethod': 'source_code',
      }),
    ]);
  });

  tearDown(() {
    patients.observableMap.clear();
    appointments.observableMap.clear();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();
    treatmentHistory.observableMap.clear();
    therapyGroups.debugSetCanonicalAliases(const {});
    procedureCatalog.debugSetCanonicalAliases(const {});
    launch.exitLocalDemo();
  });

  testWidgets('a DentalWin group includes every procedure in the group',
      (tester) async {
    await _pumpScreen(tester);
    await _chooseGroup(tester, 'Εμφυτεύματα');

    // The two new DentalWin choices are additive; the original Apexo picker
    // and its predefined treatment options remain available.
    expect(find.byType(ComboBox<String>), findsNWidgets(3));
    expect(
      tester.widgetList<ComboBox<String>>(find.byType(ComboBox<String>)).any(
          (box) =>
              box.items?.any((item) => item.value == 'extraction') ?? false),
      isTrue,
    );

    expect(_patientRow(nativePaltopPatientID), findsOneWidget);
    expect(_patientRow(nativeOtherPatientID), findsOneWidget);
    expect(_patientRow(importedPaltopPatientID), findsOneWidget);
    expect(_patientRow(nativeSurgeryPatientID), findsNothing);
    expect(
      tester
          .widget<ComboBox<String>>(
              find.byKey(const Key('patients-treatment-procedure-filter')))
          .value,
      isNull,
    );
  });

  testWidgets('a procedure narrows the group and finds imported history',
      (tester) async {
    await _pumpScreen(tester);
    await _chooseGroup(tester, 'Εμφυτεύματα');
    await _chooseProcedure(tester, 'Εμφύτευμα Paltop');

    expect(_patientRow(nativePaltopPatientID), findsOneWidget);
    expect(_patientRow(importedPaltopPatientID), findsOneWidget);
    expect(_patientRow(nativeOtherPatientID), findsNothing);
    expect(_patientRow(nativeSurgeryPatientID), findsNothing);
  });

  testWidgets('changing group clears the exact procedure choice',
      (tester) async {
    await _pumpScreen(tester);
    await _chooseGroup(tester, 'Εμφυτεύματα');
    await _chooseProcedure(tester, 'Εμφύτευμα Paltop');
    await _chooseGroup(tester, 'Χειρουργική');

    expect(_patientRow(nativeSurgeryPatientID), findsOneWidget);
    expect(_patientRow(nativePaltopPatientID), findsNothing);
    expect(
      tester
          .widget<ComboBox<String>>(
              find.byKey(const Key('patients-treatment-procedure-filter')))
          .value,
      isNull,
    );
  });
}

OdontogramEvent _event(
  String id,
  String patientID,
  String procedureID,
  String therapyGroupID,
  String procedureName,
  String therapyGroupName,
) =>
    OdontogramEvent.fromJson({
      'id': id,
      'patientID': patientID,
      'procedureID': procedureID,
      'procedureNameSnapshot': procedureName,
      'therapyGroupID': therapyGroupID,
      'therapyGroupNameSnapshot': therapyGroupName,
      'targetScope': 'tooth',
      'toothFdi': 11,
      'eventKind': 'treatment',
      'status': 'completed',
    });

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await pumpApexoApp(
    tester,
    const SizedBox(width: 1900, height: 900, child: PatientsScreen()),
  );
}

Patient _testPatient({required String id, required String name}) =>
    _PatientWithoutAvatar.fromJson(testPatient(id: id, name: name).toJson());

class _PatientWithoutAvatar extends Patient {
  _PatientWithoutAvatar.fromJson(super.json) : super.fromJson();

  @override
  String? get avatar => null;
}

Finder _patientRow(String id) => find.byWidgetPredicate(
      (widget) => widget is ListTile && widget.key == ValueKey(id),
    );

Future<void> _chooseGroup(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('patients-treatment-group-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _chooseProcedure(WidgetTester tester, String name) async {
  await tester
      .tap(find.byKey(const Key('patients-treatment-procedure-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}
