import 'package:apexo/app/routes.dart';
import 'package:apexo/features/clinical_beta/clinical_beta_screen.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/model_factory.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('Demo beta hub exposes the four clinical entry points',
      (tester) async {
    launch.enterLocalDemo();
    routes.reset();
    routes.panels([]);
    patients.observableMap.clear();
    patients.set(testPatient(id: 'patient12345678', name: 'Beta Patient'));
    addTearDown(() {
      patients.observableMap.clear();
      routes.panels([]);
      launch.exitLocalDemo();
      routes.reset();
    });

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpApexoApp(tester, const ClinicalBetaScreen());

    expect(find.byKey(const ValueKey('clinical-beta-home')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('clinical-beta-odontogram')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clinical-beta-periodontal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clinical-beta-treatment-planning')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clinical-beta-catalogue')),
      findsOneWidget,
    );

    final odontogramButton = find.descendant(
      of: find.byKey(const ValueKey('clinical-beta-odontogram')),
      matching: find.byType(FilledButton),
    );
    await tester.tap(odontogramButton);
    await tester.pump(const Duration(milliseconds: 150));

    expect(routes.panels(), hasLength(1));
    expect(
      routes.panels().single.selectedTab(),
      ClinicalBetaScreen.odontogramTabIndex,
    );
  });
}
