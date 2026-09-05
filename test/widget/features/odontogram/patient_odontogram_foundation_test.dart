import 'package:apexo/features/odontogram/odontogram_event_model.dart';
import 'package:apexo/features/odontogram/odontogram_event_store.dart';
import 'package:apexo/features/odontogram/dental_surface_selector.dart';
import 'package:apexo/features/odontogram/odontogram_assets.dart';
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
  testWidgets(
      'uses structured DentalWin defaults in an editable surface selector',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    final group = TherapyGroup.fromJson({
      'id': 'group1234567890',
      'name': 'Οδον. Χειρουργική 1',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure86107',
      'sourceCode': '86107',
      'name': 'Ανασύσταση κοπτικής γωνίας m',
      'therapyGroupID': group.id,
      'toothRequired': true,
      'defaultDrawingBehavior': 'filling',
      'defaultSurfaces': ['mesial', 'facial'],
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
          width: 1400,
          child: PatientOdontogram(patientID: 'patient1234567'),
        ),
      ),
    );

    final selector = tester.widget<DentalSurfaceSelector>(
      find.byKey(DentalSurfaceSelector.rootKey(11)),
    );
    expect(
      selector.selectedSurfaces,
      unorderedEquals({DentalSurface.mesial, DentalSurface.facial}),
    );
    expect(find.byKey(const Key('automatic-procedure-handling')), findsOne);

    await _tapSurface(tester, fdi: 11, surface: DentalSurface.mesial);
    await _tapSurface(tester, fdi: 11, surface: DentalSurface.distal);
    await tester.pump();

    await tester.tap(find.byKey(const Key('record-treatment-event')));
    await tester.pump();

    final event = odontogramEvents.forPatient('patient1234567').single;
    expect(event.targetScope.name, 'tooth');
    expect(event.toothFdi, 11);
    expect(
      event.surfaces,
      unorderedEquals(['distal', 'facial']),
    );
    expect(event.overlayKind?.name, 'filling');
    expect(event.drawsOnTooth(11), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('shows the selected tooth history beside a wide odontogram',
      (tester) async {
    launch.enterLocalDemo();
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    odontogramEvents.observableMap.clear();

    odontogramEvents.set(OdontogramEvent.fromJson({
      'id': 'selectedtooth46event',
      'patientID': 'patient1234567',
      'targetScope': 'tooth',
      'toothFdi': 46,
      'surfaces': ['occlusalIncisal'],
      'procedureID': 'procedure123456',
      'procedureNameSnapshot': 'Completed restoration 46',
      'therapyGroupNameSnapshot': 'Restorative',
      'status': 'completed',
    }));

    tester.view.physicalSize = const Size(1400, 1500);
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
          width: 1400,
          child: PatientOdontogram(patientID: 'patient1234567'),
        ),
      ),
    );

    expect(find.byKey(const Key('odontogram-chart-history-wide')), findsOne);
    final selectedPanel =
        find.byKey(const Key('selected-tooth-treatment-panel'));
    expect(
      find.descendant(
        of: selectedPanel,
        matching: find.text('Completed restoration 46'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('odontogram-tooth-46')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: selectedPanel,
        matching: find.text('Completed restoration 46'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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

    await tester.tap(find.byKey(const Key('Bridge work_clear')));
    await tester.pumpAndSettle();
    final openProcedureList = find.descendant(
      of: find.byKey(const Key('procedure-selector')),
      matching: find.byIcon(WindowsIcons.chevron_down),
    );
    await tester.tap(openProcedureList);
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
        Key('odontogram-overlay-${event.id}-rootCanal-11-facial'),
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
        'id': 'event-$overlay-$fdi',
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
      'id': 'event-bridge',
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
      ('event-crown-11', 'crown', 11),
      ('event-rootCanal-13', 'rootCanal', 13),
      ('event-extraction-14', 'extraction', 14),
      ('event-implant-16', 'implant', 16),
      ('event-bridge', 'bridge', 24),
      ('event-bridge', 'bridge', 25),
      ('event-bridge', 'bridge', 26),
    ]) {
      expect(
        find.byKey(
          Key(
            'odontogram-overlay-${expectation.$1}-${expectation.$2}-${expectation.$3}-facial',
          ),
        ),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _tapSurface(
  WidgetTester tester, {
  required int fdi,
  required DentalSurface surface,
}) async {
  final rect = tester.getRect(
    find.byKey(DentalSurfaceSelector.rootKey(fdi)),
  );
  final mesialOnLeft = fdi ~/ 10 == 2 || fdi ~/ 10 == 3;
  final normalized = switch (surface) {
    DentalSurface.mesial => Offset(mesialOnLeft ? 0.15 : 0.85, 0.50),
    DentalSurface.distal => Offset(mesialOnLeft ? 0.85 : 0.15, 0.50),
    DentalSurface.facial => const Offset(0.50, 0.85),
    DentalSurface.oral => const Offset(0.50, 0.15),
    DentalSurface.occlusalIncisal => const Offset(0.50, 0.50),
    DentalSurface.wholeTooth =>
      throw ArgumentError('Whole tooth is not a selectable zone'),
  };
  await tester.tapAt(
    Offset(
      rect.left + rect.width * normalized.dx,
      rect.top + rect.height * normalized.dy,
    ),
  );
}
