import 'package:apexo_patient_intake/intake_schema.dart';
import 'package:apexo_patient_intake/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts in staff preparation without an Apexo login', (
    tester,
  ) async {
    await tester.pumpWidget(const PracticeIntakeApp());

    expect(find.text('Staff preparation'), findsOneWidget);
    expect(find.text('Test the form'), findsOneWidget);
    expect(find.textContaining('Apexo login'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  test('questionnaire keeps the canonical version and stable unique IDs', () {
    expect(questionnaireVersion, 'practice-medical-history-2026-09-04-v2');
    final ids = intakeQuestions.map((question) => question.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      ids,
      containsAll(<String>[
        'allergies',
        'antibiotic_allergy',
        'cardiovascular_disease',
        'antiresorptive_therapy',
        'adverse_dental_reaction',
      ]),
    );
    expect(ids, isNot(contains('penicillin_allergy')));
    expect(ids, isNot(contains('latex_allergy')));
    expect(ids, isNot(contains('alcohol_use')));
  });

  testWidgets('navigation buttons rise above the Android keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const PracticeIntakeApp());
    await tester.tap(find.text('Test the form'));
    await tester.pumpAndSettle();

    final next = find.byKey(const ValueKey('next_button'));
    final originalBottom = tester.getBottomLeft(next).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final keyboardBottom = tester.getBottomLeft(next).dy;

    expect(keyboardBottom, lessThan(originalBottom - 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes the entire intake on a phone-sized screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const PracticeIntakeApp());
    await tester.tap(find.text('Test the form'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field_family_name')),
      'Test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field_given_name')),
      'Patient',
    );
    await tester.enterText(find.byKey(const ValueKey('date_day')), '01');
    await tester.enterText(find.byKey(const ValueKey('date_month')), '01');
    await tester.enterText(find.byKey(const ValueKey('date_year')), '1990');
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field_mobile')),
      '6900000000',
    );
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    for (final question in intakeQuestions) {
      final key = ValueKey('answer_${question.id}_no');
      final finder = find.byKey(key);
      if (finder.evaluate().isEmpty) continue;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    for (final question in intakeQuestions) {
      final finder = find.byKey(ValueKey('answer_${question.id}_no'));
      if (finder.evaluate().isEmpty) continue;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    for (final question in intakeQuestions) {
      final finder = find.byKey(ValueKey('answer_${question.id}_no'));
      if (finder.evaluate().isEmpty) continue;
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(
      find.byKey(const ValueKey('field_signed_name')),
      'Test Patient',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('signature_pad')));
    await tester.drag(
      find.byKey(const ValueKey('signature_pad')),
      const Offset(100, 30),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Test completed'), findsOneWidget);
    expect(
      find.text('This testing build did not save or send the answers.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
