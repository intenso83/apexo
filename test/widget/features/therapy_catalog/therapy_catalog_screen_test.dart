import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_screen.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/encode.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('administrator can hide and restore a catalogue procedure',
      (tester) async {
    final previousAdminCollectionId = login.adminCollectionId;
    final previousToken = login.token;
    final previousPb = login.pb;

    login.adminCollectionId = 'admin-collection';
    login.token = 'header.${encode('admin-collection')}.signature';
    login.pb = null;
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    therapyGroups.changes.clear();
    procedureCatalog.changes.clear();
    therapyGroups.debugSetCanonicalAliases(const {});
    procedureCatalog.debugSetCanonicalAliases(const {});

    final group = TherapyGroup.fromJson({
      'id': 'group-1',
      'name': 'Restorative',
    });
    final procedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure-1',
      'name': 'Composite filling',
      'therapyGroupID': group.id,
      'hidden': false,
    });
    therapyGroups.set(group);
    procedureCatalog.set(procedure);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
      therapyGroups.changes.clear();
      procedureCatalog.changes.clear();
      therapyGroups.debugSetCanonicalAliases(const {});
      procedureCatalog.debugSetCanonicalAliases(const {});
      login.adminCollectionId = previousAdminCollectionId;
      login.token = previousToken;
      login.pb = previousPb;
    });

    await pumpApexoApp(tester, const TherapyCatalogScreen());

    final visibilityButton = find.byKey(
      const ValueKey('toggle-procedure-visibility-procedure-1'),
    );
    expect(visibilityButton, findsOneWidget);
    expect(procedureCatalog.get(procedure.id)?.hidden, isFalse);

    await tester.tap(visibilityButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hide-procedure-dialog')), findsOneWidget);
    expect(procedureCatalog.get(procedure.id)?.hidden, isFalse);

    await tester.tap(find.byKey(const Key('hide-procedure-confirm')));
    await tester.pumpAndSettle();

    expect(procedureCatalog.get(procedure.id), isNotNull);
    expect(procedureCatalog.get(procedure.id)?.hidden, isTrue);
    expect(find.text('Composite filling'), findsOneWidget);
    expect(visibilityButton, findsOneWidget);

    await tester.tap(visibilityButton);
    await tester.pumpAndSettle();

    expect(procedureCatalog.get(procedure.id)?.hidden, isFalse);
    expect(find.text('Composite filling'), findsOneWidget);
  });
}
