import 'dart:io';

import 'package:apexo/features/medical_history/medical_history_questionnaire.dart';
import 'package:apexo/features/patient_intake/patient_intake_mapper.dart';
import 'package:apexo/features/patient_intake/patient_intake_submission.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PatientIntakeSubmission submission({String amka = '01019000000'}) {
    return PatientIntakeSubmission.fromJson({
      'id': 'intakesubmit001',
      'received_at': '2026-09-02T10:00:00Z',
      'packet': {
        'packet_version': 'practice-patient-intake-2026-09-02-v1',
        'questionnaire_version': PracticeMedicalHistoryQuestionnaire.version,
        'language_code': 'el',
        'patient_confirmed': true,
        'personal': {
          'family_name': 'Δημητρίου',
          'given_name': 'Μαρία',
          'father_name': 'Γεώργιος',
          'date_of_birth': '01/01/1990',
          'mobile': '690 000 0000',
          'email': 'MARIA@example.com',
          'address': 'Οδός 1',
          'city': 'Θεσσαλονίκη',
          'postal_code': '54622',
          'amka': amka,
          'afm': '123456789',
          'insurance': 'ΕΟΠΥΥ',
        },
        'medical_history': {
          'answers': {
            for (final question
                in PracticeMedicalHistoryQuestionnaire.questions)
              question.id: {
                'value': question.id == 'allergies' ? 'yes' : 'no',
                if (question.id == 'allergies') 'notes': 'Latex',
              },
          },
        },
        'signature': {'type': 'typed_name', 'name': 'Μαρία Δημητρίου'},
      },
    });
  }

  test('maps practice-form personal data into the Apexo patient shape', () {
    final patient = PatientIntakeMapper.newPatient(submission());

    expect(patient.surname, 'Δημητρίου');
    expect(patient.firstName, 'Μαρία');
    expect(patient.patronymic, 'Γεώργιος');
    expect(patient.birthDate, DateTime(1990, 1, 1));
    expect(patient.city, 'Θεσσαλονίκη');
    expect(patient.amka, '01019000000');
    expect(patient.contacts, hasLength(2));
    expect(
        patient.legacyCustomFields['intake_submission_id'], 'intakesubmit001');
  });

  test('matches old DentalWin/Apexo data and never overwrites existing values',
      () {
    final existing = Patient.fromJson({
      'title': 'Existing title',
      'surname': 'Δημητρίου',
      'first_name': 'Μαρία',
      'amka': '01019000000',
      'city': 'Existing city',
    });
    final incoming = submission();

    expect(
      PatientIntakeMapper.likelyMatches(incoming, [existing]),
      [existing],
    );
    PatientIntakeMapper.mergeMissingPersonalData(existing, incoming);
    expect(existing.city, 'Existing city');
    expect(existing.addressLine, 'Οδός 1');
    expect(existing.contacts, hasLength(2));
  });

  test('tablet and server schemas contain every canonical question id',
      () async {
    final appSchema =
        await File('intake_app/lib/intake_schema.dart').readAsString();
    final serverHook = await File(
      'server/pocketbase/pb_hooks/apexo_intake.pb.js',
    ).readAsString();

    for (final question in PracticeMedicalHistoryQuestionnaire.questions) {
      expect(appSchema, contains("id: '${question.id}'"));
      expect(serverHook, contains('"${question.id}"'));
    }
  });
}
