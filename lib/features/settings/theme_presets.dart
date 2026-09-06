import 'package:fluent_ui/fluent_ui.dart';

/// Curated interface palettes. Clinical colours are deliberately not part of
/// this model: treatment states, warnings and urgency indicators keep their
/// existing semantic colours.
enum ApexoThemePreset {
  classic,
  aegean,
  sage,
  warmSand;

  String get labelKey => switch (this) {
        ApexoThemePreset.classic => 'themePresetClassic',
        ApexoThemePreset.aegean => 'themePresetAegean',
        ApexoThemePreset.sage => 'themePresetSage',
        ApexoThemePreset.warmSand => 'themePresetWarmSand',
      };

  Color get accent => switch (this) {
        ApexoThemePreset.classic => Colors.blue.normal,
        ApexoThemePreset.aegean => const Color(0xFF087E8B),
        ApexoThemePreset.sage => const Color(0xFF557A5C),
        ApexoThemePreset.warmSand => const Color(0xFFA6603D),
      };

  /// Three colours used by the compact preview shown in Settings.
  List<Color> get previewColors => switch (this) {
        ApexoThemePreset.classic => const [
            Color(0xFF0078D4),
            Color(0xFFF3F2F1),
            Color(0xFFFFFFFF),
          ],
        ApexoThemePreset.aegean => const [
            Color(0xFF087E8B),
            Color(0xFFEDF7F8),
            Color(0xFFFFFFFF),
          ],
        ApexoThemePreset.sage => const [
            Color(0xFF557A5C),
            Color(0xFFEEF4EA),
            Color(0xFFFFFFFF),
          ],
        ApexoThemePreset.warmSand => const [
            Color(0xFFA6603D),
            Color(0xFFF6EDE2),
            Color(0xFFFFFDF9),
          ],
      };

  /// The clinical-panel workspace keeps Apexo's original gradient for the
  /// Classic preset and follows the selected palette for the curated themes.
  List<Color> get workspaceGradient => switch (this) {
        ApexoThemePreset.classic => const [
            Color(0xFFF8FCFD),
            Color(0xFFEDF7F8),
          ],
        ApexoThemePreset.aegean => const [
            Color(0xFFF8FCFC),
            Color(0xFFE7F3F5),
          ],
        ApexoThemePreset.sage => const [
            Color(0xFFFAFCF8),
            Color(0xFFEAF2E6),
          ],
        ApexoThemePreset.warmSand => const [
            Color(0xFFFFFCF8),
            Color(0xFFF5E8DA),
          ],
      };

  BoxDecoration workspaceDecoration(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return BoxDecoration(
          color: themeData(brightness).scaffoldBackgroundColor);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: workspaceGradient,
      ),
    );
  }

  FluentThemeData themeData(Brightness brightness) {
    if (this == ApexoThemePreset.classic) {
      return brightness == Brightness.dark
          ? FluentThemeData.dark()
          : FluentThemeData.light();
    }

    final isDark = brightness == Brightness.dark;
    final palette = isDark ? _darkSurfacePalette : _lightSurfacePalette;

    return FluentThemeData(
      brightness: brightness,
      accentColor: accent.toAccentColor(),
      scaffoldBackgroundColor: palette.scaffold,
      acrylicBackgroundColor: palette.acrylic,
      micaBackgroundColor: palette.mica,
      menuColor: palette.menu,
      cardColor: palette.card,
    );
  }

  _SurfacePalette get _lightSurfacePalette => switch (this) {
        ApexoThemePreset.classic => throw StateError('Classic uses defaults'),
        ApexoThemePreset.aegean => const _SurfacePalette(
            scaffold: Color(0xFFF4FAFB),
            acrylic: Color(0xFFF8FCFC),
            mica: Color(0xFFEDF7F8),
            menu: Color(0xFFFAFDFD),
            card: Color(0xFFFFFFFF),
          ),
        ApexoThemePreset.sage => const _SurfacePalette(
            scaffold: Color(0xFFF6F8F3),
            acrylic: Color(0xFFFAFCF8),
            mica: Color(0xFFEEF4EA),
            menu: Color(0xFFFBFCF9),
            card: Color(0xFFFFFFFF),
          ),
        ApexoThemePreset.warmSand => const _SurfacePalette(
            scaffold: Color(0xFFFBF7F1),
            acrylic: Color(0xFFFFFAF5),
            mica: Color(0xFFF6EDE2),
            menu: Color(0xFFFFFCF8),
            card: Color(0xFFFFFDF9),
          ),
      };

  _SurfacePalette get _darkSurfacePalette => switch (this) {
        ApexoThemePreset.classic => throw StateError('Classic uses defaults'),
        ApexoThemePreset.aegean => const _SurfacePalette(
            scaffold: Color(0xFF121C1F),
            acrylic: Color(0xFF172428),
            mica: Color(0xFF0E1719),
            menu: Color(0xFF172428),
            card: Color(0xFF1D2C30),
          ),
        ApexoThemePreset.sage => const _SurfacePalette(
            scaffold: Color(0xFF171D18),
            acrylic: Color(0xFF202821),
            mica: Color(0xFF121713),
            menu: Color(0xFF202821),
            card: Color(0xFF283129),
          ),
        ApexoThemePreset.warmSand => const _SurfacePalette(
            scaffold: Color(0xFF211A16),
            acrylic: Color(0xFF2B211B),
            mica: Color(0xFF19130F),
            menu: Color(0xFF2B211B),
            card: Color(0xFF342820),
          ),
      };
}

ApexoThemePreset themePresetFromId(String? id) {
  return ApexoThemePreset.values.firstWhere(
    (preset) => preset.name == id,
    orElse: () => ApexoThemePreset.classic,
  );
}

class _SurfacePalette {
  final Color scaffold;
  final Color acrylic;
  final Color mica;
  final Color menu;
  final Color card;

  const _SurfacePalette({
    required this.scaffold,
    required this.acrylic,
    required this.mica,
    required this.menu,
    required this.card,
  });
}
