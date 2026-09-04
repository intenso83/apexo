import 'dart:io';

import 'package:apexo_patient_intake/form_configuration.dart';
import 'package:apexo_patient_intake/intake_pdf_generator.dart';
import 'package:apexo_patient_intake/intake_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generates a complete PDF with a raster signature image', (
    tester,
  ) async {
    final draft = IntakeDraft()
      ..language = 'el'
      ..privacyAccepted = true
      ..confirmed = true
      ..signedName = 'Μαρία Δοκιμή'
      ..signatureStrokes = const [
        [
          {'x': 0.10, 'y': 0.65},
          {'x': 0.28, 'y': 0.22},
          {'x': 0.46, 'y': 0.72},
          {'x': 0.68, 'y': 0.30},
          {'x': 0.88, 'y': 0.58},
        ],
      ];
    draft.personal.addAll({
      'family_name': 'Δοκιμή',
      'given_name': 'Μαρία',
      'date_of_birth': '12/06/1992',
      'mobile': '6900000000',
    });
    for (final answer in draft.answers.values) {
      answer.value = 'no';
    }
    draft.answers['antibiotic_allergy']!
      ..value = 'yes'
      ..notes = 'Amoxicillin - εξάνθημα';
    draft.answers['blood_pressure_disorder']!
      ..value = 'yes'
      ..selections = ['high'];
    final configuration = IntakeFormConfiguration.defaults();

    await tester.runAsync(() async {
      final signature = await IntakePdfGenerator.renderSignatureImage(
        draft.signatureStrokes,
      );
      final pdf = await const IntakePdfGenerator().generate(
        draft: draft,
        configuration: configuration,
        generatedAt: DateTime(2026, 9, 4, 12, 30),
      );

      expect(signature.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      expect(pdf.length, greaterThan(10000));
      expect(pdf.length, lessThan(IntakePdfGenerator.maxPdfBytes));

      if (const bool.fromEnvironment('WRITE_INTAKE_PDF_SAMPLE')) {
        final output = File('../output/pdf/patient-intake-signed-sample.pdf');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(pdf, flush: true);
      }
    });
  });
}
