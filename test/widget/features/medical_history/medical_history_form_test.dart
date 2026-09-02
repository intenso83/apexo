import 'package:apexo/features/medical_history/medical_history_form.dart';
import 'package:apexo/features/medical_history/medical_history_model.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual medical-history entry works at Android phone width',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MedicalHistoryRevision? saved;
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PatientMedicalHistory(
              patientID: 'synthetic-patient',
              revisions: const [],
              onRevisionSaved: (revision) => saved = revision,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(WK.btnNewMedicalHistory));
    await tester.pumpAndSettle();

    final diabetesYes = find.byKey(const ValueKey('medical_diabetes_yes'));
    await tester.scrollUntilVisible(
      diabetesYes,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(diabetesYes);
    await tester.pumpAndSettle();

    final notes = find.byKey(const ValueKey('medical_notes_diabetes'));
    await tester.enterText(
      find.descendant(of: notes, matching: find.byType(TextBox)),
      'Synthetic controlled condition',
    );

    await tester.scrollUntilVisible(
      find.byKey(WK.btnSaveMedicalHistory),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(WK.btnSaveMedicalHistory));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(saved, isNotNull);
    expect(saved!.patientID, 'synthetic-patient');
    expect(saved!.status, MedicalHistoryStatus.pendingReview);
    expect(saved!.answers['diabetes']!.value, MedicalHistoryAnswerValue.yes);
    expect(saved!.answers['diabetes']!.notes, 'Synthetic controlled condition');
  });
}
