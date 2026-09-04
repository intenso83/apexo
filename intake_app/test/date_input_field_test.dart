import 'package:apexo_patient_intake/date_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('date segments advance and produce DD/MM/YYYY', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateInputField(controller: controller, label: 'Date of birth'),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('date_day')), '12');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('date_month')))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.enterText(find.byKey(const ValueKey('date_month')), '6');
    await tester.pump();
    expect(controller.text, '12/06/');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('date_year')))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.enterText(find.byKey(const ValueKey('date_year')), '1992');
    expect(controller.text, '12/06/1992');
    expect(isValidIntakeDate(controller.text), isTrue);
  });

  test(
    'date validation rejects impossible and incorrectly formatted dates',
    () {
      expect(isValidIntakeDate('29/02/2024'), isTrue);
      expect(isValidIntakeDate('29/02/2023'), isFalse);
      expect(isValidIntakeDate('31/04/1992'), isFalse);
      expect(isValidIntakeDate('1/6/1992'), isFalse);
    },
  );
}
