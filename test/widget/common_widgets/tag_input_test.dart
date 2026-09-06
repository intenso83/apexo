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

  testWidgets('refreshes suggestions when an empty dependent picker changes',
      (tester) async {
    late StateSetter updateHost;
    var suggestions = [
      TagInputItem(value: 'surgery', label: 'Oral surgery treatment'),
    ];

    await pumpApexoApp(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          updateHost = setState;
          return Center(
            child: SizedBox(
              width: 360,
              child: TagInputWidget(
                key: const Key('dependent-picker'),
                strict: true,
                limit: 1,
                initialValue: const [],
                suggestions: suggestions,
                onChanged: (_) {},
              ),
            ),
          );
        },
      ),
    );

    updateHost(() {
      suggestions = [
        TagInputItem(value: 'implant', label: 'Implant treatment'),
      ];
    });
    await tester.pumpAndSettle();

    final openSuggestions = find.descendant(
      of: find.byKey(const Key('dependent-picker')),
      matching: find.byIcon(WindowsIcons.chevron_down),
    );
    await tester.tap(openSuggestions);
    await tester.pumpAndSettle();

    expect(find.text('Implant treatment'), findsOneWidget);
    expect(find.text('Oral surgery treatment'), findsNothing);
  });
}
