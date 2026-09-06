import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/patient_odontogram.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets(
      'switching from oral surgery to implants refreshes procedure choices',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();
    therapyGroups.debugSetCanonicalAliases(const {});
    procedureCatalog.debugSetCanonicalAliases(const {});

    final surgery = TherapyGroup.fromJson({
      'id': 'surgery-group-1',
      'name': 'Οδοντική χειρουργική 1',
      'displayOrder': 1,
    });
    final implants = TherapyGroup.fromJson({
      'id': 'implants-group1',
      'name': 'Εμφυτεύματα',
      'displayOrder': 2,
    });
    final surgeryProcedure = ProcedureCatalogItem.fromJson({
      'id': 'surgery-proc-01',
      'name': 'Εξαγωγή φρονιμίτη',
      'therapyGroupID': surgery.id,
    });
    final implantProcedure = ProcedureCatalogItem.fromJson({
      'id': 'implant-proc-01',
      'name': 'Τοποθέτηση εμφυτεύματος',
      'therapyGroupID': implants.id,
    });
    therapyGroups.setAll([surgery, implants]);
    procedureCatalog.setAll([surgeryProcedure, implantProcedure]);

    tester.view.physicalSize = const Size(1400, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
      odontogramEvents.observableMap.clear();
      therapyGroups.debugSetCanonicalAliases(const {});
      procedureCatalog.debugSetCanonicalAliases(const {});
      launch.exitLocalDemo();
    });

    await pumpApexoApp(
      tester,
      const SingleChildScrollView(
        child: SizedBox(
          width: 1200,
          child: PatientOdontogram(patientID: 'patient1234567'),
        ),
      ),
    );

    final groupPicker = find.byType(ComboBox<String>);
    expect(groupPicker, findsOneWidget);
    expect(tester.widget<ComboBox<String>>(groupPicker).value, surgery.id);

    await tester.tap(groupPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text(implants.title).last);
    await tester.pumpAndSettle();

    expect(tester.widget<ComboBox<String>>(groupPicker).value, implants.id);
    final procedurePicker = find.byKey(const Key('procedure-selector'));
    expect(
      tester
          .widget<TagInputWidget>(procedurePicker)
          .suggestions
          .map((item) => item.label),
      [implantProcedure.title],
    );

    final openProcedureList = find.descendant(
      of: procedurePicker,
      matching: find.byIcon(WindowsIcons.chevron_down),
    );
    await tester.tap(openProcedureList);
    await tester.pumpAndSettle();

    expect(find.text(implantProcedure.title), findsOneWidget);
    expect(find.text(surgeryProcedure.title), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
