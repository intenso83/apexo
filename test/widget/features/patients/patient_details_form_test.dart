import 'package:apexo/features/patients/patient_details_form.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    Patient patient, {
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApexoApp(
      tester,
      ScaffoldPage(
        content: SingleChildScrollView(
          child: PatientDetailsForm(patient: patient),
        ),
      ),
    );
  }

  testWidgets('renders the approved patient editor at Android phone width',
      (tester) async {
    final patient = Patient.fromJson({
      'id': 'mobilepatient01',
      'registration_number': '000123',
      'surname': 'Papadopoulou',
      'first_name': 'Maria',
      'city': 'Athens',
    });

    await pumpForm(tester, patient);

    expect(find.byKey(WK.fieldPatientSurname), findsOneWidget);
    expect(find.byKey(WK.fieldPatientFirstName), findsOneWidget);
    expect(find.text('000123'), findsOneWidget);
    expect(find.text('Identity and demographics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits structured names and keeps the display name compatible',
      (tester) async {
    final patient = Patient.fromJson({'id': 'newpatient00001'});
    await pumpForm(tester, patient);

    await tester.enterText(
      find.byKey(WK.fieldPatientSurname),
      'Dimitrakopoulos',
    );
    await tester.enterText(find.byKey(WK.fieldPatientFirstName), 'Evripidis');
    await tester.pump();

    expect(patient.surname, 'Dimitrakopoulos');
    expect(patient.firstName, 'Evripidis');
    expect(patient.title, 'Dimitrakopoulos Evripidis');
  });

  testWidgets('adds a mobile contact and preserves its raw value',
      (tester) async {
    final patient = Patient.fromJson({
      'id': 'contactpatient1',
      'surname': 'Test',
      'first_name': 'Patient',
    });
    await pumpForm(tester, patient);

    final addContact = find.byKey(WK.btnAddPatientContact);
    await tester.ensureVisible(addContact);
    await tester.tap(addContact);
    await tester.pumpAndSettle();

    final contactValue = find.byKey(
      const ValueKey('patient_contact_value_0'),
    );
    await tester.ensureVisible(contactValue);
    await tester.enterText(contactValue, '+30 691 234 5678');
    await tester.pump();

    expect(patient.contacts, hasLength(1));
    expect(patient.contacts.single.type, 'mobile');
    expect(patient.contacts.single.rawValue, '+30 691 234 5678');
    expect(patient.contacts.single.normalizedValue, '+306912345678');
    expect(patient.contacts.single.isPrimary, isTrue);
  });

  testWidgets('an unrelated edit does not discard legacy patient values',
      (tester) async {
    final patient = Patient.fromJson({
      'id': 'legacypatient01',
      'title': 'Legacy Patient',
      'phone': '+30 210 123 4567',
      'email': 'legacy@example.test',
      'amka': '00123456789',
      'legacy_custom_fields': {'auxiliary_1': 'keep me'},
    });
    await pumpForm(tester, patient);

    await tester.enterText(find.byKey(WK.fieldPatientSurname), 'Legacy');
    await tester.pump();

    final json = patient.toJson();
    expect(json['phone'], '+302101234567');
    expect(json['email'], 'legacy@example.test');
    expect(json['amka'], '00123456789');
    expect(json['legacy_custom_fields'], {'auxiliary_1': 'keep me'});
  });
}
