import 'package:apexo/features/patients/patient_fields_prototype.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('patient fields prototype renders real values read-only',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final patient = Patient.fromJson({
      'id': 'prototypewidget',
      'registration_number': '000123',
      'surname': 'Dimitrakopoulos',
      'first_name': 'Evripidis',
      'contacts': [
        {
          'id': 'contactwidget1',
          'type': 'mobile',
          'raw_value': '+30 691 234 5678',
          'normalized_value': '+306912345678',
          'is_primary': true,
        },
      ],
      'city': 'Thessaloniki',
    });

    await pumpApexoApp(
      tester,
      ScaffoldPage(content: PatientFieldsPrototype(patient: patient)),
    );

    expect(find.text('Patient Fields Preview'), findsOneWidget);
    expect(find.text('000123'), findsOneWidget);
    expect(find.text('Dimitrakopoulos'), findsOneWidget);
    expect(find.text('Evripidis'), findsOneWidget);
    expect(find.text('+30 691 234 5678'), findsOneWidget);
    expect(find.text('Thessaloniki'), findsOneWidget);
    expect(find.byType(TextBox), findsNothing);
  });
}
