import 'package:apexo_patient_intake/intake_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('positive antibiotic and kidney/liver answers require details', () {
    final answer = IntakeAnswer()..value = 'yes';
    expect(hasValidRequiredDetails('antibiotic_allergy', answer), isFalse);
    expect(hasValidRequiredDetails('liver_kidney_disease', answer), isFalse);

    answer.notes = 'Previous reaction';
    expect(hasValidRequiredDetails('antibiotic_allergy', answer), isTrue);
    expect(hasValidRequiredDetails('liver_kidney_disease', answer), isTrue);
  });

  test('positive smoking answer requires a realistic numeric daily amount', () {
    final answer = IntakeAnswer()..value = 'yes';
    for (final invalid in ['', 'many', '0', '201']) {
      answer.notes = invalid;
      expect(hasValidRequiredDetails('smoking', answer), isFalse);
    }
    answer.notes = '12';
    expect(hasValidRequiredDetails('smoking', answer), isTrue);
  });

  test('packet records GDPR acknowledgment and structured selections', () {
    final draft = IntakeDraft()..privacyAccepted = true;
    draft.answers['liver_kidney_disease']!
      ..value = 'yes'
      ..notes = 'Monitored condition'
      ..selections = ['kidney', 'liver'];

    final packet = draft.toJson();
    final history = packet['medical_history'] as Map<String, dynamic>;
    final answers = history['answers'] as Map<String, dynamic>;
    final structured = answers['liver_kidney_disease'] as Map<String, dynamic>;
    expect(packet['gdpr_acknowledged'], isTrue);
    expect(structured['selections'], ['kidney', 'liver']);
  });
}
