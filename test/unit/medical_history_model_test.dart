import 'package:apexo/features/medical_history/medical_history_model.dart';
import 'package:apexo/features/medical_history/medical_history_questionnaire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('practice medical-history questionnaire', () {
    test('uses stable unique IDs and covers every paper question number', () {
      final questions = PracticeMedicalHistoryQuestionnaire.questions;
      final ids = questions.map((question) => question.id).toSet();
      final paperNumbers = questions
          .map((question) => question.paperNumber)
          .whereType<int>()
          .toSet();

      expect(ids.length, questions.length);
      expect(paperNumbers, containsAll(List<int>.generate(23, (i) => i + 1)));
      expect(PracticeMedicalHistoryQuestionnaire.questionsByID,
          contains('penicillin_allergy'));
      expect(PracticeMedicalHistoryQuestionnaire.questionsByID,
          contains('latex_allergy'));
      expect(PracticeMedicalHistoryQuestionnaire.questionsByID,
          contains('antiresorptive_therapy'));
    });

    test('provides the paper languages with English fallback', () {
      final allergy =
          PracticeMedicalHistoryQuestionnaire.questionsByID['allergies']!;
      expect(allergy.label('el'), contains('Αλλεργ'));
      expect(allergy.label('de'), contains('Allerg'));
      expect(allergy.label('es'), allergy.label('en'));
    });
  });

  group('MedicalHistoryRevision', () {
    test('round-trips structured responses and provenance', () {
      final revision = MedicalHistoryRevision.fromJson({
        'patient_id': 'patient-1',
        'revision_number': 2,
        'previous_revision_id': 'revision-1',
        'source': MedicalHistorySource.tablet,
        'status': MedicalHistoryStatus.pendingReview,
        'language_code': 'el',
        'created_at': '2026-09-02T09:00:00Z',
        'patient_confirmed': true,
        'signature': {'present': true, 'capture_method': 'tablet'},
        'answers': {
          'diabetes': {
            'value': MedicalHistoryAnswerValue.yes,
            'notes': 'Synthetic test note',
          },
        },
        'provenance': {'session_id': 'synthetic-session'},
      });

      final decoded = MedicalHistoryRevision.fromJson(revision.toJson());

      expect(decoded.patientID, 'patient-1');
      expect(decoded.revisionNumber, 2);
      expect(decoded.patientConfirmed, isTrue);
      expect(decoded.answers['diabetes']!.value, MedicalHistoryAnswerValue.yes);
      expect(decoded.answers['diabetes']!.notes, 'Synthetic test note');
      expect(decoded.signature['capture_method'], 'tablet');
      expect(decoded.provenance['session_id'], 'synthetic-session');
    });

    test('creates an independent next revision without copying signature', () {
      final current = MedicalHistoryRevision.fromJson({
        'id': 'revision-1',
        'patient_id': 'patient-1',
        'revision_number': 1,
        'status': MedicalHistoryStatus.confirmed,
        'signature': {'present': true},
        'answers': {
          'smoking': {'value': MedicalHistoryAnswerValue.no},
        },
      });

      final next = current.copyAsNextRevision(languageCode: 'de');
      next.answers['smoking']!.value = MedicalHistoryAnswerValue.yes;

      expect(next.id, isNot(current.id));
      expect(next.previousRevisionID, current.id);
      expect(next.revisionNumber, 2);
      expect(next.status, MedicalHistoryStatus.draft);
      expect(next.languageCode, 'de');
      expect(next.signature, isEmpty);
      expect(current.answers['smoking']!.value, MedicalHistoryAnswerValue.no);
    });

    test('maps only confirmed DentalWin fields and retains raw payload', () {
      final revision = MedicalHistoryRevision.fromDentalWinStage(
        patientID: 'patient-1',
        stage: {
          'stage_key': 'medical-history:synthetic-1',
          'reason_for_visit': 'Synthetic reason',
          'present_condition': 'Synthetic present condition',
          'medicines_text': 'Synthetic medicine text',
          'diseases_surgeries_text': 'Synthetic disease text',
          'pregnancy_text': 'Synthetic pregnancy source text',
          'general_notes': 'Synthetic general note',
          'penicillin_raw': -1,
          'latex_raw': 0,
          'hypertension_raw': 'YES',
          'cardiovascular_raw': 'ambiguous',
        },
      );

      expect(revision.source, MedicalHistorySource.dentalWin);
      expect(revision.status, MedicalHistoryStatus.pendingReview);
      expect(revision.reasonForVisit, 'Synthetic reason');
      expect(revision.diseasesSurgeries, 'Synthetic disease text');
      expect(revision.answers['penicillin_allergy']!.value,
          MedicalHistoryAnswerValue.yes);
      expect(revision.answers['latex_allergy']!.value,
          MedicalHistoryAnswerValue.no);
      expect(revision.answers['blood_pressure_disorder']!.value,
          MedicalHistoryAnswerValue.yes);
      expect(revision.answers['cardiovascular_disease']!.value,
          MedicalHistoryAnswerValue.unknown);
      expect(revision.answers['pregnancy']!.value,
          MedicalHistoryAnswerValue.unknown);
      expect(revision.answers['pregnancy']!.notes,
          'Synthetic pregnancy source text');
      expect(revision.answers.values.every((answer) => answer.requiresReview),
          isTrue);
      expect(revision.legacyRawPayload['stage_key'],
          'medical-history:synthetic-1');
    });
  });
}
