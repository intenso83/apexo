import 'package:apexo/features/therapy_catalog/procedure_catalog_model.dart';
import 'package:apexo/features/therapy_catalog/therapy_catalog_store.dart';
import 'package:apexo/features/therapy_catalog/therapy_group_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TherapyGroup importedGroup({
    required String id,
    String stageKey = 'therapy-group:4',
    String batchID = 'batch-current',
    String name = 'Fixed prosthodontics',
    String sourceID = '4',
  }) {
    return TherapyGroup.fromJson({
      'id': id,
      'name': name,
      'sourceID': sourceID,
      'migration': {
        'source_system': 'DentalWin',
        'source_stage_key': stageKey,
        'batch_id': batchID,
      },
    });
  }

  ProcedureCatalogItem importedProcedure({
    required String id,
    String stageKey = 'procedure:86181',
    String batchID = 'batch-current',
    String name = 'Zirconia crown',
    String sourceCode = '86181',
    String groupID = 'group-current',
  }) {
    return ProcedureCatalogItem.fromJson({
      'id': id,
      'name': name,
      'sourceCode': sourceCode,
      'therapyGroupID': groupID,
      'migration': {
        'source_system': 'DentalWin',
        'source_stage_key': stageKey,
        'batch_id': batchID,
      },
    });
  }

  test('maps a prior migration batch ID to the current remote group ID', () {
    final old = importedGroup(
      id: 'group-old',
      batchID: 'private-2026-08-26.phase4',
      name: 'Old translated presentation',
    );
    final current = importedGroup(
      id: 'group-current',
      batchID: 'phase6-snapshot-v2',
      name: 'Current translated presentation',
    );

    final aliases = buildCatalogueAliasMap<TherapyGroup>(
      localRecords: [old, current],
      remoteRecords: [current],
      stableIdentity: therapyGroupStableImportIdentity,
    );

    expect(aliases, {'group-old': 'group-current'});
  });

  test('does not map same-ID, user-created, or deferred local records', () {
    final current = importedGroup(id: 'group-current');
    final deferred = importedGroup(id: 'group-deferred');
    final userCreated = TherapyGroup.fromJson({
      'id': 'group-user',
      'name': 'My custom group',
    });

    final aliases = buildCatalogueAliasMap<TherapyGroup>(
      localRecords: [current, deferred, userCreated],
      remoteRecords: [current],
      stableIdentity: therapyGroupStableImportIdentity,
      deferredRecordIDs: {'group-deferred'},
    );

    expect(aliases, isEmpty);
  });

  test('keeps an imported local row when the remote identity is ambiguous', () {
    final old = importedGroup(id: 'group-old');
    final remoteA = importedGroup(id: 'group-current-a');
    final remoteB = importedGroup(id: 'group-current-b');

    final aliases = buildCatalogueAliasMap<TherapyGroup>(
      localRecords: [old, remoteA, remoteB],
      remoteRecords: [remoteA, remoteB],
      stableIdentity: therapyGroupStableImportIdentity,
    );

    expect(aliases, isEmpty);
  });

  test('does not collapse demo groups that share the demo source ID', () {
    TherapyGroup demoGroup(String id, String name) => TherapyGroup.fromJson({
          'id': id,
          'name': name,
          'sourceID': 'demo',
          'migration': {'source': 'beta_demo_fixture'},
        });
    final old = demoGroup('demo-old', 'Old demo group');
    final remoteA = demoGroup('demo-current-a', 'Surgery');
    final remoteB = demoGroup('demo-current-b', 'Endodontics');

    final aliases = buildCatalogueAliasMap<TherapyGroup>(
      localRecords: [old, remoteA, remoteB],
      remoteRecords: [remoteA, remoteB],
      stableIdentity: therapyGroupStableImportIdentity,
    );

    expect(aliases, isEmpty);
  });

  test('uses a unique legacy source ID only as a conservative fallback', () {
    final old = TherapyGroup.fromJson({
      'id': 'legacy-old',
      'name': 'Old presentation',
      'sourceID': '12',
      'migration': {'source': 'DentalWin'},
    });
    final current = TherapyGroup.fromJson({
      'id': 'legacy-current',
      'name': 'Current presentation',
      'sourceID': '12',
      'migration': {'source_system': 'DentalWin'},
    });

    final aliases = buildCatalogueAliasMap<TherapyGroup>(
      localRecords: [old, current],
      remoteRecords: [current],
      stableIdentity: therapyGroupStableImportIdentity,
    );

    expect(aliases, {'legacy-old': 'legacy-current'});
  });

  test('procedure reconciliation uses source stage identity across batches',
      () {
    final old = importedProcedure(
      id: 'procedure-old',
      batchID: 'phase4',
    );
    final current = importedProcedure(
      id: 'procedure-current',
      batchID: 'phase6-v2',
    );

    final aliases = buildCatalogueAliasMap<ProcedureCatalogItem>(
      localRecords: [old, current],
      remoteRecords: [current],
      stableIdentity: procedureStableImportIdentity,
    );

    expect(aliases, {'procedure-old': 'procedure-current'});
  });

  test('choice views hide aliases but retain old-ID history lookups', () async {
    therapyGroups.observableMap.clear();
    procedureCatalog.observableMap.clear();
    therapyGroups.changes.clear();
    procedureCatalog.changes.clear();
    therapyGroups.debugSetCanonicalAliases(const {});
    procedureCatalog.debugSetCanonicalAliases(const {});
    addTearDown(() {
      therapyGroups.observableMap.clear();
      procedureCatalog.observableMap.clear();
      therapyGroups.changes.clear();
      procedureCatalog.changes.clear();
      therapyGroups.debugSetCanonicalAliases(const {});
      procedureCatalog.debugSetCanonicalAliases(const {});
    });

    final oldGroup = importedGroup(id: 'group-old');
    final currentGroup = importedGroup(id: 'group-current');
    final customGroup = TherapyGroup.fromJson({
      'id': 'group-user',
      'name': 'My custom group',
    });
    therapyGroups.setAll([oldGroup, currentGroup, customGroup]);

    final oldProcedure = importedProcedure(
      id: 'procedure-old',
      groupID: oldGroup.id,
    );
    final currentProcedure = importedProcedure(
      id: 'procedure-current',
      groupID: currentGroup.id,
    );
    final customProcedure = ProcedureCatalogItem.fromJson({
      'id': 'procedure-user',
      'name': 'My custom procedure',
      // A locally created procedure tied to the old logical group must remain
      // available under the canonical group.
      'therapyGroupID': oldGroup.id,
    });
    procedureCatalog.setAll([
      oldProcedure,
      currentProcedure,
      customProcedure,
    ]);

    procedureCatalog.debugSetCanonicalAliases({
      oldProcedure.id: currentProcedure.id,
    });
    // Prime the grouping cache before the group reconciliation changes.
    expect(
      procedureCatalog.forGroup(oldGroup.id).map((procedure) => procedure.id),
      contains(customProcedure.id),
    );
    therapyGroups.debugSetCanonicalAliases({
      oldGroup.id: currentGroup.id,
    });
    await Future<void>.delayed(Duration.zero);

    expect(
      therapyGroups.ordered.map((group) => group.id),
      containsAll(<String>[currentGroup.id, customGroup.id]),
    );
    expect(
      therapyGroups.ordered.map((group) => group.id),
      isNot(contains(oldGroup.id)),
    );
    expect(therapyGroups.get(oldGroup.id), same(oldGroup));
    expect(procedureCatalog.get(oldProcedure.id), same(oldProcedure));
    expect(
      procedureCatalog
          .forGroup(currentGroup.id)
          .map((procedure) => procedure.id),
      containsAll(<String>[currentProcedure.id, customProcedure.id]),
    );
    expect(
      procedureCatalog.logicalRecordIDs(currentProcedure.id),
      {currentProcedure.id, oldProcedure.id},
    );
  });
}
