import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/odontogram/patient_odontogram.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/features/treatment_planning/patient_treatment_planning.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_model.dart';
import 'package:apexo/features/treatment_planning/treatment_plan_store.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('creates an alternative and adds a catalogue treatment',
      (tester) async {
    launch.enterLocalDemo();
    treatmentPlans.setAll([]);
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
    final secondProcedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure654321',
      'name': 'Ανασύσταση μύλης',
      'therapyGroupID': group.id,
      'sourceCode': '44',
      'basePrice': 90,
      'handlingMode': 'wholeTooth',
    });
    final iconProcedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure86174',
      'name': 'Icon',
      'therapyGroupID': group.id,
      'sourceCode': '86174',
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);
    procedureCatalog.set(secondProcedure);
    procedureCatalog.set(iconProcedure);

    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      treatmentPlans.setAll([]);
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
    await _waitForPlanningToLoad(tester);

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

    await tester.tap(find.byKey(const Key('odontogram-tooth-48')));
    await tester.pumpAndSettle();
    final originalItem = plan.items.single;
    expect(originalItem.toothFdi, 48);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const Key('odontogram-tooth-47')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(originalItem.toothFdi, 48);
    expect(
      tester
          .widget<PatientOdontogramChart>(
            find.byType(PatientOdontogramChart),
          )
          .selectedFdis,
      {48, 47},
    );

    // Reusing the selected catalogue procedure should add only tooth 47,
    // rather than duplicating the existing procedure on tooth 48.
    await tester.tap(find.byKey(const Key('add-treatment-plan-item')));
    await tester.pumpAndSettle();
    expect(plan.items, hasLength(2));
    expect(plan.items.map((item) => item.toothFdi).toSet(), {48, 47});
    expect(plan.items.where((item) => item.toothFdi == 48), hasLength(1));
    final newItem = plan.items.singleWhere((item) => item.toothFdi == 47);
    expect(newItem.id, isNot(originalItem.id));
    expect(newItem.quantity, 1);

    await tester.tap(find.byKey(const Key('odontogram-tooth-36')));
    await tester.pumpAndSettle();
    expect(originalItem.toothFdi, 48);
    expect(newItem.toothFdi, 36);
    expect(
      tester
          .widget<PatientOdontogramChart>(
            find.byType(PatientOdontogramChart),
          )
          .selectedFdis,
      {36},
    );
    expect(find.text('Ενδοδοντική θεραπεία γομφίου'), findsWidgets);
    expect(find.textContaining('180.00 EUR'), findsWidgets);
    expect(find.byKey(const Key('preview-treatment-plan-pdf')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('delete-plan-item-${newItem.id}')));
    await tester.pumpAndSettle();
    expect(plan.items, hasLength(1));
    await tester
        .tap(find.byKey(ValueKey('delete-plan-item-${originalItem.id}')));
    await tester.pumpAndSettle();
    expect(plan.items, isEmpty);

    // A fresh alternative can apply two different treatments to the same
    // Shift-selected teeth, with one independently editable row per tooth.
    await tester.tap(find.byKey(const Key('new-treatment-plan')));
    await tester.pumpAndSettle();
    final multiPlan = treatmentPlans
        .forPatient(patient.id)
        .singleWhere((candidate) => candidate.id != plan.id);
    await tester.tap(find.byKey(const Key('odontogram-tooth-16')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const Key('odontogram-tooth-26')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PatientOdontogramChart>(find.byType(PatientOdontogramChart))
          .selectedFdis,
      {16, 26},
    );

    await tester.tap(find.byKey(const Key('add-treatment-plan-item')));
    await tester.pumpAndSettle();
    expect(multiPlan.items, hasLength(2));
    expect(multiPlan.items.map((item) => item.toothFdi).toSet(), {16, 26});
    expect(multiPlan.gross, 360);

    await tester.tap(find.byKey(Key('${procedure.title}_clear')));
    await tester.pumpAndSettle();
    final openSecondProcedureList = find.descendant(
      of: find.byKey(const Key('treatment-plan-procedure-picker')),
      matching: find.byIcon(WindowsIcons.chevron_down),
    );
    await tester.tap(openSecondProcedureList);
    await tester.pumpAndSettle();
    await tester.tap(find.text(secondProcedure.title).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-treatment-plan-item')));
    await tester.pumpAndSettle();

    expect(multiPlan.items, hasLength(4));
    expect(multiPlan.items.map((item) => item.id).toSet(), hasLength(4));
    for (final selectedProcedure in [procedure, secondProcedure]) {
      expect(
        multiPlan.items
            .where((item) => item.procedureID == selectedProcedure.id)
            .map((item) => item.toothFdi)
            .toSet(),
        {16, 26},
      );
    }
    expect(multiPlan.gross, 540);
    for (final item in multiPlan.items) {
      expect(item.quantity, 1);
      expect(item.surfaces, ['wholeTooth']);
      expect(
        find.byKey(ValueKey('treatment-plan-ledger-row-${item.id}')),
        findsOneWidget,
      );
    }
    await _assertCustomTreatmentWorkflow(tester, patient, procedure);
  });
}

Future<void> _assertCustomTreatmentWorkflow(
  WidgetTester tester,
  Patient patient,
  ProcedureCatalogItem existingProcedure,
) async {
  final oldPlanIDs = treatmentPlans
      .forPatient(patient.id)
      .map((candidate) => candidate.id)
      .toSet();
  final catalogueSize = procedureCatalog.observableMap.values.length;
  await tester.tap(find.byKey(const Key('new-treatment-plan')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('show-custom-treatment-composer')));
  await tester.pumpAndSettle();
  final addCustom = find.byKey(const Key('add-custom-treatment-plan-item'));
  expect(tester.widget<FilledButton>(addCustom).onPressed, isNull);
  await tester.enterText(
    find.byKey(const Key('custom-treatment-name')),
    'Ειδική προσαρμογή νάρθηκα',
  );
  await tester.enterText(
    find.byKey(const Key('custom-treatment-description')),
    'Επιπλέον εργασία εκτός καταλόγου',
  );
  await tester.enterText(
    find.byKey(const Key('custom-treatment-price')),
    '85.50',
  );
  await tester.pumpAndSettle();
  await tester.tap(addCustom);
  await tester.pumpAndSettle();

  final plan = treatmentPlans
      .forPatient(patient.id)
      .singleWhere((candidate) => !oldPlanIDs.contains(candidate.id));
  expect(plan.items, hasLength(1));
  final custom = plan.items.single;
  expect(custom.isCustom, isTrue);
  expect(custom.procedureID, isEmpty);
  expect(custom.procedureNameElSnapshot, 'Ειδική προσαρμογή νάρθηκα');
  expect(custom.notes, 'Επιπλέον εργασία εκτός καταλόγου');
  expect(custom.unitPrice, 85.5);
  expect(custom.quantity, 1);
  expect(custom.toothFdi, isNull);
  expect(custom.targetScope.name, 'patient');
  expect(plan.total, 85.5);
  final reloaded = TreatmentPlanItem.fromJson(custom.toJson());
  expect(reloaded.isCustom, isTrue);
  expect(reloaded.notes, custom.notes);
  expect(procedureCatalog.observableMap.values, hasLength(catalogueSize));
  expect(procedureCatalog.get(existingProcedure.id), same(existingProcedure));
  expect(
    find.byKey(ValueKey('treatment-plan-ledger-row-${custom.id}')),
    findsOneWidget,
  );

  await tester.enterText(
    find.byKey(ValueKey('plan-item-custom-name-${custom.id}')),
    'Ειδική προσαρμογή νάρθηκα — επανέλεγχος',
  );
  await tester.pumpAndSettle();
  expect(
    treatmentPlans
        .forPatient(patient.id)
        .singleWhere((candidate) => candidate.id == plan.id)
        .items
        .single
        .procedureNameElSnapshot,
    'Ειδική προσαρμογή νάρθηκα — επανέλεγχος',
  );

  // The same composer can optionally create one independently priced row
  // for each Shift-selected tooth, without creating a catalogue entry.
  await tester.tap(find.byKey(const Key('odontogram-tooth-16')));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tap(find.byKey(const Key('odontogram-tooth-26')));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('custom-treatment-tooth-scope')));
  await tester.enterText(
    find.byKey(const Key('custom-treatment-name')),
    'Ειδική αποκατάσταση',
  );
  await tester.enterText(
    find.byKey(const Key('custom-treatment-description')),
    'Χωριστή χρέωση ανά δόντι',
  );
  await tester.enterText(
    find.byKey(const Key('custom-treatment-price')),
    '40',
  );
  await tester.pumpAndSettle();
  await tester.tap(addCustom);
  await tester.pumpAndSettle();

  expect(plan.items, hasLength(3));
  final toothItems = plan.items.where((item) => item.id != custom.id).toList();
  expect(toothItems.map((item) => item.toothFdi).toSet(), {16, 26});
  expect(toothItems.map((item) => item.id).toSet(), hasLength(2));
  for (final item in toothItems) {
    expect(item.isCustom, isTrue);
    expect(item.procedureID, isEmpty);
    expect(item.procedureNameElSnapshot, 'Ειδική αποκατάσταση');
    expect(item.notes, 'Χωριστή χρέωση ανά δόντι');
    expect(item.targetScope.name, 'tooth');
    expect(item.unitPrice, 40);
    expect(item.quantity, 1);
  }
  expect(plan.total, 165.5);
  expect(procedureCatalog.observableMap.values, hasLength(catalogueSize));
}

Future<void> _waitForPlanningToLoad(WidgetTester tester) async {
  // AssetBundle decoding completes on the real async queue rather than the
  // widget test's fake clock. Its duration varies across consecutive tests.
  final createButton = find.byKey(const Key('new-treatment-plan'));
  for (var attempt = 0;
      attempt < 20 && createButton.evaluate().isEmpty;
      attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
  expect(createButton, findsOneWidget);
}
