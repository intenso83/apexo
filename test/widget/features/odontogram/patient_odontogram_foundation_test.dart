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
  testWidgets('records a tooth treatment without selecting a surface',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Restorative',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Composite filling',
      'therapyGroupID': group.id,
      'targetScope': 'tooth',
      'surfaceSelectionMode': 'optional',
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);

    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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

    final unspecified = tester.widget<ToggleButton>(
      find.byKey(const Key('surface-unspecified')),
    );
    expect(unspecified.checked, isTrue);

    final record = tester.widget<FilledButton>(
      find.byKey(const Key('record-treatment-event')),
    );
    expect(record.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('record-treatment-event')));
    await tester.pump();

    final events = odontogramEvents.forPatient('patient1234567');
    expect(events, hasLength(1));
    expect(events.single.surfaces, isEmpty);
    expect(events.single.drawsOnTooth(11), isFalse);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('opens bridge and removable prosthesis target editors',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Prosthetics',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Prosthetic treatment',
      'therapyGroupID': group.id,
      'targetScope': 'tooth',
      'surfaceSelectionMode': 'optional',
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);

    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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

    await tester.tap(find.byKey(const Key('treatment-target-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bridge').last);
    await tester.pumpAndSettle();

    expect(find.text('Bridge units'), findsOneWidget);
    expect(find.byKey(const Key('add-bridge-unit')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('record-treatment-event')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('treatment-target-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Removable prosthesis').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('removable-arch')), findsOneWidget);
    expect(find.byKey(const Key('add-removable-component')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('record-treatment-event')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
