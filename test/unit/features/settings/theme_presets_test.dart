import 'package:apexo/features/settings/theme_presets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apexo theme presets', () {
    test('unknown and missing identifiers retain the classic appearance', () {
      expect(themePresetFromId(null), ApexoThemePreset.classic);
      expect(themePresetFromId('retired-theme'), ApexoThemePreset.classic);
    });

    test('classic is exactly the stock Fluent light and dark palette', () {
      final classicLight = ApexoThemePreset.classic.themeData(Brightness.light);
      final stockLight = FluentThemeData.light();
      final classicDark = ApexoThemePreset.classic.themeData(Brightness.dark);
      final stockDark = FluentThemeData.dark();

      expect(classicLight.accentColor, stockLight.accentColor);
      expect(classicLight.scaffoldBackgroundColor,
          stockLight.scaffoldBackgroundColor);
      expect(classicLight.menuColor, stockLight.menuColor);
      expect(classicLight.cardColor, stockLight.cardColor);
      expect(classicDark.accentColor, stockDark.accentColor);
      expect(classicDark.scaffoldBackgroundColor,
          stockDark.scaffoldBackgroundColor);
      expect(classicDark.menuColor, stockDark.menuColor);
      expect(classicDark.cardColor, stockDark.cardColor);
    });

    test('curated palettes have distinct accents and gentle light surfaces',
        () {
      final curated = ApexoThemePreset.values.skip(1).toList();
      final accentValues = curated.map((preset) => preset.accent).toSet();

      expect(accentValues, hasLength(curated.length));
      for (final preset in curated) {
        final theme = preset.themeData(Brightness.light);
        expect(theme.brightness, Brightness.light);
        expect(theme.accentColor.normal, preset.accent);
        expect(
            theme.scaffoldBackgroundColor.computeLuminance(), greaterThan(.85));
        expect(theme.menuColor.computeLuminance(), greaterThan(.85));
      }
    });

    test('every curated palette keeps dark mode genuinely dark', () {
      for (final preset in ApexoThemePreset.values.skip(1)) {
        final theme = preset.themeData(Brightness.dark);
        expect(theme.brightness, Brightness.dark);
        expect(theme.accentColor.normal, preset.accent);
        expect(theme.scaffoldBackgroundColor.computeLuminance(), lessThan(.05));
        expect(theme.menuColor.computeLuminance(), lessThan(.05));
      }
    });

    test('each preset exposes a compact three-colour preview', () {
      for (final preset in ApexoThemePreset.values) {
        expect(preset.previewColors, hasLength(3));
        expect(preset.previewColors.first, preset.accent);
      }
    });

    test('classic retains the existing clinical workspace gradient', () {
      final decoration =
          ApexoThemePreset.classic.workspaceDecoration(Brightness.light);
      final gradient = decoration.gradient! as LinearGradient;

      expect(
        gradient.colors,
        const [Color(0xFFF8FCFD), Color(0xFFEDF7F8)],
      );
    });

    test('dark clinical workspaces use the selected dark surface', () {
      for (final preset in ApexoThemePreset.values) {
        final decoration = preset.workspaceDecoration(Brightness.dark);
        expect(decoration.gradient, isNull);
        expect(
          decoration.color,
          preset.themeData(Brightness.dark).scaffoldBackgroundColor,
        );
      }
    });
  });
}
