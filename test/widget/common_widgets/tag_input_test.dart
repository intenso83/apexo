import 'package:apexo/common_widgets/tag_input.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('searches rich metadata but renders the compact label',
      (tester) async {
    await pumpApexoApp(
      tester,
      Center(
        child: SizedBox(
          width: 360,
          child: TagInputWidget(
            key: const Key('patient-picker'),
            strict: true,
            limit: 1,
            initialValue: const [],
            suggestions: [
              TagInputItem(
                value: 'patient-1',
                label: 'Ashley Adams',
                searchText:
                    'Ashley Adams · +30 6912345678 · ashley@example.com',
              ),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final input = find.descendant(
      of: find.byKey(const Key('patient-picker')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(input, '691234');
    await tester.pumpAndSettle();

    expect(find.text('Ashley Adams'), findsOneWidget);
    expect(
      find.text('Ashley Adams · +30 6912345678 · ashley@example.com'),
      findsNothing,
    );
  });
}
