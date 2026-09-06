import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  testWidgets('time input displays and opens in 24-hour mode', (tester) async {
    final originalLocale = localSettings.selectedLocale;
    localSettings.selectedLocale = 0;
    addTearDown(() => localSettings.selectedLocale = originalLocale);

    await pumpApexoApp(
      tester,
      DateTimePicker(
        initValue: DateTime(2026, 9, 6, 23, 7),
        pickTime: true,
        showButton: false,
        onChange: (_) {},
      ),
    );

    expect(find.text('🕒 23:07'), findsAtLeastNWidgets(1));
    expect(find.textContaining('PM'), findsNothing);

    await tester.tap(find.text('🕒 23:07').last);
    await tester.pumpAndSettle();

    expect(find.byType(material.TimePickerDialog), findsOneWidget);
    expect(
      tester
          .widgetList<MediaQuery>(find.byType(MediaQuery))
          .any((query) => query.data.alwaysUse24HourFormat),
      isTrue,
    );

    material.Navigator.of(
      tester.element(find.byType(material.TimePickerDialog)),
    ).pop();
    await tester.pumpAndSettle();
  });
}
