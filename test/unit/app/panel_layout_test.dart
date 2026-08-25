import 'package:apexo/app/panel_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sidePanelWidthForLayout', () {
    test('patient panel uses half of a wide desktop window', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 2000,
          minimized: false,
          desktopWidthFraction: 0.5,
        ),
        1000,
      );
    });

    test('ordinary desktop panels keep the compact width', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 2000,
          minimized: false,
        ),
        compactPanelWidth,
      );
    });

    test('mobile patient panel keeps the compact overlay width', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 430,
          minimized: false,
          desktopWidthFraction: 0.5,
        ),
        compactPanelWidth,
      );
    });

    test('minimized narrow mobile panel fits the screen', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 420,
          minimized: true,
          desktopWidthFraction: 0.5,
        ),
        420,
      );
    });

    test('wide panel always leaves compact space for the main screen', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 800,
          minimized: false,
          desktopWidthFraction: 0.9,
        ),
        450,
      );
    });

    test('focus mode uses the full desktop width', () {
      expect(
        sidePanelWidthForLayout(
          layoutWidth: 2000,
          minimized: false,
          desktopWidthFraction: 0.5,
          desktopExpanded: true,
        ),
        2000,
      );
    });
  });

  group('mainScreenWidthForLayout', () {
    test('split mode leaves room for the patient panel', () {
      expect(
        mainScreenWidthForLayout(
          layoutWidth: 2000,
          panelVisible: true,
          panelWidth: 1000,
          desktopExpanded: false,
        ),
        995,
      );
    });

    test('focus mode keeps the main screen safely behind the panel', () {
      expect(
        mainScreenWidthForLayout(
          layoutWidth: 2000,
          panelVisible: true,
          panelWidth: 2000,
          desktopExpanded: true,
        ),
        2000,
      );
    });
  });
}
