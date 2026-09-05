import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/features/treatment_planning/patient_treatment_planning.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('creates an alternative and adds a catalogue treatment',
      (tester) async {
    launch.enterLocalDemo();
    treatmentPlans.observableMap.clear();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    final patient = Patient.fromJson({
      'id': 'patient1234567',
      'title': 'Demo Patient',
    });
    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Ενδοδοντία',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Ενδοδοντική θεραπεία γομφίου',
      'therapyGroupID': group.id,
      'sourceCode': '43',
      'basePrice': 180,
      'handlingMode': 'wholeTooth',
      'odontogramOverlay': 'rootCanal',
    });
    final iconProcedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure86174',
      'name': 'Icon',
      'therapyGroupID': group.id,
      'sourceCode': '86174',
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);
    procedureCatalog.set(iconProcedure);

    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      treatmentPlans.observableMap.clear();
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
      launch.exitLocalDemo();
    });

    await pumpApexoApp(
      tester,
      SingleChildScrollView(
        child: SizedBox(
          width: 1200,
          child: PatientTreatmentPlanning(patient: patient),
        ),
      ),
    );
    // AssetBundle decoding completes on the real async queue rather than the
    // widget test's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-treatment-plan')));
    await tester.pumpAndSettle();
    expect(treatmentPlans.forPatient(patient.id), hasLength(1));

    expect(
      tester
          .widget<TagInputWidget>(
            find.byKey(const Key('treatment-plan-procedure-picker')),
          )
          .initialValue,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('add-treatment-plan-item')),
          )
          .onPressed,
      isNull,
    );
    final openProcedureList = find.descendant(
      of: find.byKey(const Key('treatment-plan-procedure-picker')),
      matching: find.byIcon(WindowsIcons.chevron_down),
    );
    await tester.tap(openProcedureList);
    await tester.pumpAndSettle();
    await tester.tap(find.text(procedure.title).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-treatment-plan-item')));
    await tester.pumpAndSettle();

    final plan = treatmentPlans.forPatient(patient.id).single;
    expect(plan.items, hasLength(1));
    expect(plan.items.single.unitPrice, 180);
    expect(plan.items.single.toothFdi, 11);
    expect(plan.items.single.surfaces, ['wholeTooth']);
    expect(
      find.byKey(ValueKey('treatment-plan-ledger-row-${plan.items.single.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('odontogram-tooth-16')));
    await tester.pumpAndSettle();
    expect(plan.items.single.toothFdi, 16);
    expect(find.text('Ενδοδοντική θεραπεία γομφίου'), findsWidgets);
    expect(find.textContaining('180.00 EUR'), findsWidgets);
    expect(find.byKey(const Key('preview-treatment-plan-pdf')), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('delete-plan-item-${plan.items.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(plan.items, isEmpty);
  });
}
