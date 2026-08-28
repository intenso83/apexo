import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/patient_odontogram.dart';
import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/services/launch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
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
      'handlingMode': 'surfaceBased',
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
    final bridgeProcedure = ProcedureCatalogItem.fromJson({
      'id': 'bridgeprocedure1',
      'name': 'Bridge work',
      'therapyGroupID': group.id,
      'handlingMode': 'bridge',
    });
    final removableProcedure = ProcedureCatalogItem.fromJson({
      'id': 'removableproc12',
      'name': 'Removable work',
      'therapyGroupID': group.id,
      'handlingMode': 'removableProsthesis',
    });
    therapyGroups.set(group);
    procedureCatalog.set(bridgeProcedure);
    procedureCatalog.set(removableProcedure);

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

    expect(find.text('Bridge units'), findsOneWidget);
    expect(find.byKey(const Key('add-bridge-unit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('odontogram-tooth-14')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const Key('odontogram-tooth-16')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(find.text('Tooth 14 · Abutment'), findsOneWidget);
    expect(find.text('Tooth 15 · Pontic'), findsOneWidget);
    expect(find.text('Tooth 16 · Abutment'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('record-treatment-event')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('procedure-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Removable work').last);
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

  testWidgets('whole-tooth therapies need no extra surface click',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Endodontics',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Root canal',
      'therapyGroupID': group.id,
      'handlingMode': 'wholeTooth',
      'targetScope': 'tooth',
      'surfaceSelectionMode': 'automaticWholeTooth',
      'defaultSurfaces': ['wholeTooth'],
      'odontogramOverlay': 'rootCanal',
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

    expect(find.byKey(const Key('whole-tooth-automatic')), findsOneWidget);
    expect(find.byKey(const Key('surface-unspecified')), findsNothing);
    expect(find.byKey(const Key('treatment-target-scope')), findsNothing);

    await tester.tap(find.byKey(const Key('record-treatment-event')));
    await tester.pump();

    final event = odontogramEvents.forPatient('patient1234567').single;
    expect(event.toothFdi, 11);
    expect(event.surfaces, ['wholeTooth']);
    expect(event.overlayKind?.name, 'rootCanal');
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('odontogram-overlay-rootCanal-11-facial'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('renders the whole-tooth and bridge overlay pilot',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Overlay pilot',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure123456',
      'name': 'Crown',
      'therapyGroupID': group.id,
      'handlingMode': 'wholeTooth',
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);

    void addToothEvent(int fdi, String overlay, String status) {
      odontogramEvents.set(OdontogramEvent.fromJson({
        'patientID': 'patient1234567',
        'toothFdi': fdi,
        'surfaces': ['wholeTooth'],
        'procedureID': 'procedure-$overlay-$fdi',
        'procedureNameSnapshot': overlay,
        'therapyGroupNameSnapshot': 'Overlay pilot',
        'overlayKind': overlay,
        'status': status,
      }));
    }

    addToothEvent(11, 'crown', 'completed');
    addToothEvent(13, 'rootCanal', 'existing');
    addToothEvent(14, 'extraction', 'planned');
    addToothEvent(16, 'implant', 'completed');
    odontogramEvents.set(OdontogramEvent.fromJson({
      'patientID': 'patient1234567',
      'targetScope': 'bridge',
      'procedureID': 'procedure-bridge',
      'procedureNameSnapshot': 'Bridge',
      'therapyGroupNameSnapshot': 'Overlay pilot',
      'overlayKind': 'bridge',
      'status': 'planned',
      'bridgeUnits': [
        {'toothFdi': 24, 'role': 'abutment'},
        {'toothFdi': 25, 'role': 'pontic'},
        {'toothFdi': 26, 'role': 'abutment'},
      ],
    }));

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

    for (final expectation in const [
      ('crown', 11),
      ('rootCanal', 13),
      ('extraction', 14),
      ('implant', 16),
      ('bridge', 24),
      ('bridge', 25),
      ('bridge', 26),
    ]) {
      expect(
        find.byKey(
          Key(
            'odontogram-overlay-${expectation.$1}-${expectation.$2}-facial',
          ),
        ),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
