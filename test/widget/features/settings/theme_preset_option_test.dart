import 'package:apexo/features/settings/settings_screen.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/settings/theme_presets.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('theme option shows its name and three colour swatches',
      (tester) async {
    final originalLocale = localSettings.selectedLocale;
    localSettings.selectedLocale = 0;
    addTearDown(() => localSettings.selectedLocale = originalLocale);

    await tester.pumpWidget(
      const FluentApp(
        home: Center(
          child: ThemePresetOption(preset: ApexoThemePreset.aegean),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('theme_preset_option_aegean')), findsOneWidget);
    expect(
        find.byKey(const Key('theme_preset_swatches_aegean')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Txt && widget.data == 'Aegean',
      ),
      findsOneWidget,
    );

    final swatches = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(const Key('theme_preset_swatches_aegean')),
        matching: find.byType(Container),
      ),
    );
    expect(swatches, hasLength(3));
  });
}
