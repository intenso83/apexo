import 'dart:convert';

import 'package:apexo/core/model.dart';
import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/odontogram/odontogram_overlay_model.dart';
import 'package:apexo/features/odontogram/treatment_target.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';
import 'package:apexo/utils/logger.dart';
import 'package:flutter/foundation.dart';

import 'procedure_catalog_model.dart';
import 'procedure_handling_classifier.dart';
import 'therapy_catalog_demo.dart';
import 'therapy_group_model.dart';

class TherapyGroups extends Store<TherapyGroup> {
  TherapyGroups()
      : super(
          modeling: TherapyGroup.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: _syncStart,
          onSyncEnd: _syncEnd,
        );

  Map<String, String> _localAliasToCanonicalID = const {};
  SaveRemote? _lastReconciledRemote;
  int? _lastReconciledRemoteVersion;

  /// Resolves a catalogue group choice to the record that exists on the
  /// current server. Historical clinical records can still look up the old ID
  /// with [get], while new catalogue choices use the canonical ID.
  String canonicalID(String id) => _localAliasToCanonicalID[id] ?? id;

  List<TherapyGroup> get ordered {
    final result = present.values
        .where((group) => !_localAliasToCanonicalID.containsKey(group.id))
        .toList();
    result.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      return order != 0 ? order : a.title.compareTo(b.title);
    });
    return List.unmodifiable(result);
  }

  @override
  void init() {
    super.init();
    _activateStore(
      this,
      'therapy_groups',
      onPersistenceSessionActivated: _resetCanonicalAliases,
    );
  }

  @override
  Future<List<SyncResult>> synchronize() async {
    final result = await super.synchronize();
    await _refreshCanonicalAliases();
    return result;
  }

  Future<void> _refreshCanonicalAliases() async {
    final snapshot = await _loadAuthoritativeCatalogueSnapshot(
      store: this,
      previousRemote: _lastReconciledRemote,
      previousVersion: _lastReconciledRemoteVersion,
      stableIdentity: therapyGroupStableImportIdentity,
    );
    if (snapshot == null) return;
    _lastReconciledRemote = snapshot.remote;
    _lastReconciledRemoteVersion = snapshot.version;
    if (mapEquals(_localAliasToCanonicalID, snapshot.aliases)) return;
    _localAliasToCanonicalID = Map.unmodifiable(snapshot.aliases);
    procedureCatalog._clearCache();
    observableMap.notifyView();
  }

  void _resetCanonicalAliases() {
    _localAliasToCanonicalID = const {};
    _lastReconciledRemote = null;
    _lastReconciledRemoteVersion = null;
    procedureCatalog._clearCache();
  }

  @visibleForTesting
  void debugSetCanonicalAliases(Map<String, String> aliases) {
    _localAliasToCanonicalID = Map.unmodifiable(aliases);
    procedureCatalog._clearCache();
    observableMap.notifyView();
  }
}

class ProcedureCatalog extends Store<ProcedureCatalogItem> {
  ProcedureCatalog()
      : super(
          modeling: ProcedureCatalogItem.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: _syncStart,
          onSyncEnd: _syncEnd,
        );

  Map<String, List<ProcedureCatalogItem>>? _byGroup;
  Map<String, String> _localAliasToCanonicalID = const {};
  SaveRemote? _lastReconciledRemote;
  int? _lastReconciledRemoteVersion;

  void _clearCache([_]) => _byGroup = null;

  /// Returns the current-server ID for a stale imported catalogue ID.
  String canonicalID(String id) => _localAliasToCanonicalID[id] ?? id;

  /// All locally retained IDs for the same logical procedure. Consumers with
  /// ID-keyed auxiliary data (for example laboratory prices) can use this to
  /// fall back to a historical alias without rewriting that data.
  Set<String> logicalRecordIDs(String id) {
    final canonical = canonicalID(id);
    return {
      canonical,
      for (final entry in _localAliasToCanonicalID.entries)
        if (entry.value == canonical) entry.key,
    };
  }

  Map<String, List<ProcedureCatalogItem>> get byGroup {
    return _byGroup ??= _buildByGroup();
  }

  Map<String, List<ProcedureCatalogItem>> _buildByGroup() {
    final result = <String, List<ProcedureCatalogItem>>{};
    for (final item in present.values) {
      if (_localAliasToCanonicalID.containsKey(item.id)) continue;
      final groupID = therapyGroups.canonicalID(item.therapyGroupID);
      result.putIfAbsent(groupID, () => []).add(item);
    }
    for (final items in result.values) {
      items.sort((a, b) => a.title.compareTo(b.title));
    }
    return result;
  }

  List<ProcedureCatalogItem> forGroup(String groupID) =>
      List.unmodifiable(byGroup[groupID] ?? const []);

  ProcedureHandlingDecision handlingDecision(ProcedureCatalogItem item) {
    final explicit = item.handlingMode;
    if (explicit != null) {
      return ProcedureHandlingDecision(
        mode: explicit,
        inferred: false,
        needsReview: false,
        rule: 'explicit',
      );
    }
    final legacy = item.legacyHandlingMode;
    if (legacy != null) {
      return ProcedureHandlingDecision(
        mode: legacy,
        inferred: true,
        needsReview: false,
        rule: 'legacy_fields',
      );
    }
    final structured = _structuredHandlingDecision(item);
    if (structured != null) return structured;
    final classified = classifyProcedureHandling(
      procedureName: item.title,
      groupName: therapyGroups.get(item.therapyGroupID)?.title ?? '',
    );
    if (classified.needsReview && item.toothRequired == false) {
      return const ProcedureHandlingDecision(
        mode: ProcedureHandlingMode.patientLevel,
        inferred: true,
        needsReview: false,
        rule: 'legacy_no_tooth',
      );
    }
    return classified;
  }

  OdontogramOverlayKind overlayFor(ProcedureCatalogItem item) {
    final explicit = item.odontogramOverlay;
    if (explicit != null) return explicit;
    final fromDrawingBehavior = switch (item.defaultDrawingBehavior) {
      OdontogramDrawingBehavior.filling => OdontogramOverlayKind.filling,
      OdontogramDrawingBehavior.crown ||
      OdontogramDrawingBehavior.veneer =>
        OdontogramOverlayKind.crown,
      null => null,
    };
    return fromDrawingBehavior ??
        inferOdontogramOverlay(
          procedureName: item.title,
          groupName: therapyGroups.get(item.therapyGroupID)?.title ?? '',
          targetScope: handlingDecision(item).mode.targetScope,
        );
  }

  /// Uses verified structured DentalWin defaults before falling back to words
  /// in a translated procedure name. Older pilot records predate the explicit
  /// handling-mode fields but already retain these drawing and surface facts.
  ProcedureHandlingDecision? _structuredHandlingDecision(
    ProcedureCatalogItem item,
  ) {
    if (item.toothRequired == false) return null;
    switch (item.defaultDrawingBehavior) {
      case OdontogramDrawingBehavior.filling:
        if (!_hasValidEditableSurfaceDefaults(item)) return null;
        return const ProcedureHandlingDecision(
          mode: ProcedureHandlingMode.surfaceBased,
          inferred: true,
          needsReview: false,
          rule: 'structured_filling_defaults',
        );
      case OdontogramDrawingBehavior.crown:
      case OdontogramDrawingBehavior.veneer:
        return const ProcedureHandlingDecision(
          mode: ProcedureHandlingMode.wholeTooth,
          inferred: true,
          needsReview: false,
          rule: 'structured_whole_tooth_drawing',
        );
      case null:
        return null;
    }
  }

  bool _hasValidEditableSurfaceDefaults(ProcedureCatalogItem item) {
    const editable = {
      'mesial',
      'distal',
      'facial',
      'oral',
      'occlusalIncisal',
    };
    final surfaces = item.defaultSurfaces;
    if (surfaces.isEmpty ||
        surfaces.any((surface) => !editable.contains(surface)) ||
        surfaces.toSet().length != surfaces.length) {
      return false;
    }
    const cervical = {'facial', 'oral'};
    return item.defaultCervicalSurfaces.every(
      (surface) => cervical.contains(surface) && surfaces.contains(surface),
    );
  }

  bool requiresLaboratory(ProcedureCatalogItem item) {
    if (item.requiresLaboratory != null) return item.requiresLaboratory!;
    final group = therapyGroups.get(item.therapyGroupID)?.title ?? '';
    final text = '${item.title} $group'.toLowerCase();
    final mode = handlingDecision(item).mode;
    if (mode == ProcedureHandlingMode.bridge ||
        mode == ProcedureHandlingMode.removableProsthesis) {
      return true;
    }
    return RegExp(
      r'προσθετ|στεφαν|γεφυρ|ένθετ|ενθετ|επένθετ|επενθετ|όψη|οψη|implant crown|crown|bridge|veneer|inlay|onlay|denture|prosthe',
    ).hasMatch(text);
  }

  List<ProcedureCatalogItem> get laboratoryProcedures {
    final result = present.values
        .where((item) =>
            !_localAliasToCanonicalID.containsKey(item.id) &&
            !item.hidden &&
            requiresLaboratory(item))
        .toList();
    result.sort((a, b) => a.title.compareTo(b.title));
    return List.unmodifiable(result);
  }

  @override
  void set(ProcedureCatalogItem item) {
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<ProcedureCatalogItem> items) {
    super.setAll(items);
    _clearCache();
  }

  @override
  void init() {
    super.init();
    observableMap.observe(_clearCache);
    therapyGroups.observableMap.observe(_clearCache);
    _activateStore(
      this,
      'procedure_catalog',
      onPersistenceSessionActivated: _resetCanonicalAliases,
      onLocalDemoActivated: () async {
        if (therapyGroups.present.isNotEmpty || present.isNotEmpty) return;
        final demo = await loadDemoTherapyCatalogue();
        therapyGroups.setAll(demo.groups);
        setAll(demo.procedures);
      },
    );
  }

  @override
  Future<List<SyncResult>> synchronize() async {
    final result = await super.synchronize();
    await _refreshCanonicalAliases();
    return result;
  }

  Future<void> _refreshCanonicalAliases() async {
    final snapshot = await _loadAuthoritativeCatalogueSnapshot(
      store: this,
      previousRemote: _lastReconciledRemote,
      previousVersion: _lastReconciledRemoteVersion,
      stableIdentity: procedureStableImportIdentity,
    );
    if (snapshot == null) return;
    _lastReconciledRemote = snapshot.remote;
    _lastReconciledRemoteVersion = snapshot.version;
    if (mapEquals(_localAliasToCanonicalID, snapshot.aliases)) return;
    _localAliasToCanonicalID = Map.unmodifiable(snapshot.aliases);
    _clearCache();
    observableMap.notifyView();
  }

  void _resetCanonicalAliases() {
    _localAliasToCanonicalID = const {};
    _lastReconciledRemote = null;
    _lastReconciledRemoteVersion = null;
    _clearCache();
  }

  @visibleForTesting
  void debugSetCanonicalAliases(Map<String, String> aliases) {
    _localAliasToCanonicalID = Map.unmodifiable(aliases);
    _clearCache();
    observableMap.notifyView();
  }
}

/// A stable identity for an imported group. Migration batch IDs and record IDs
/// are intentionally excluded because both change when a guarded migration is
/// rebuilt against the same server URL.
@visibleForTesting
String? therapyGroupStableImportIdentity(TherapyGroup group) {
  return _stableImportIdentity(
    migration: group.migration,
    fallbackKind: 'group-source-id',
    fallbackValue: group.sourceID,
  );
}

/// A stable identity for an imported procedure. [sourceCode] is only a
/// fallback for older imports that did not retain a source stage key.
@visibleForTesting
String? procedureStableImportIdentity(ProcedureCatalogItem procedure) {
  return _stableImportIdentity(
    migration: procedure.migration,
    fallbackKind: 'procedure-source-code',
    fallbackValue: procedure.sourceCode,
  );
}

String? _stableImportIdentity({
  required Map<String, dynamic> migration,
  required String fallbackKind,
  required String fallbackValue,
}) {
  final sourceSystem = _firstNonEmpty(migration, const [
    'source_system',
    'sourceSystem',
    'source',
  ]);
  final normalizedSystem = sourceSystem.toLowerCase();
  final stageKey = _firstNonEmpty(migration, const [
    'source_stage_key',
    'sourceStageKey',
    'stage_key',
    'stageKey',
  ]);
  if (stageKey.isNotEmpty) {
    return 'stage:$normalizedSystem:$stageKey';
  }
  final normalizedFallback = fallbackValue.trim();
  if (normalizedFallback.isEmpty) return null;
  return '$fallbackKind:$normalizedSystem:$normalizedFallback';
}

String _firstNonEmpty(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Returns local imported aliases that can be mapped unambiguously to a
/// current remote record. This is deliberately identity-based: titles are
/// presentation data and are never used for reconciliation.
///
/// Records stay in local persistence and in [Store.docs], so historical
/// clinical references keep resolving. The returned map is only used to hide
/// obsolete aliases from new catalogue choices. Deferred records are retained
/// as choices until their local edit has been synchronized or reviewed.
@visibleForTesting
Map<String, String> buildCatalogueAliasMap<T extends Model>({
  required Iterable<T> localRecords,
  required Iterable<T> remoteRecords,
  required String? Function(T record) stableIdentity,
  Set<String> deferredRecordIDs = const {},
}) {
  final localIDs = localRecords.map((record) => record.id).toSet();
  final remoteIDs = remoteRecords.map((record) => record.id).toSet();
  final remoteByIdentity = <String, Set<String>>{};
  for (final record in remoteRecords) {
    final identity = stableIdentity(record);
    if (identity == null) continue;
    remoteByIdentity.putIfAbsent(identity, () => <String>{}).add(record.id);
  }

  final aliases = <String, String>{};
  for (final record in localRecords) {
    final localID = record.id;
    if (remoteIDs.contains(localID) || deferredRecordIDs.contains(localID)) {
      continue;
    }
    final identity = stableIdentity(record);
    if (identity == null) continue;
    final canonicalCandidates = remoteByIdentity[identity];
    if (canonicalCandidates == null || canonicalCandidates.length != 1) {
      continue;
    }
    final canonicalID = canonicalCandidates.single;
    // A normal synchronization should already have loaded the authoritative
    // row. If it has not, retain the old choice rather than making the logical
    // catalogue item disappear from the UI.
    if (!localIDs.contains(canonicalID)) continue;
    aliases[localID] = canonicalID;
  }
  return Map.unmodifiable(aliases);
}

class _AuthoritativeCatalogueSnapshot {
  final SaveRemote remote;
  final int version;
  final Map<String, String> aliases;

  const _AuthoritativeCatalogueSnapshot({
    required this.remote,
    required this.version,
    required this.aliases,
  });
}

Future<_AuthoritativeCatalogueSnapshot?>
    _loadAuthoritativeCatalogueSnapshot<T extends Model>({
  required Store<T> store,
  required SaveRemote? previousRemote,
  required int? previousVersion,
  required String? Function(T record) stableIdentity,
}) async {
  final remote = store.remote;
  final local = store.local;
  if (remote == null || local == null || !remote.isOnline) return null;

  try {
    final remoteVersion = await remote.getVersion();
    if (identical(previousRemote, remote) && previousVersion == remoteVersion) {
      return null;
    }

    // A version-zero read is an authoritative, bounded snapshot of this one
    // catalogue store. It is only repeated when that store's remote version
    // changes, avoiding a full catalogue download on every sync request.
    final remoteSnapshot = await remote.getSince(version: 0);
    if (!identical(store.remote, remote) || !identical(store.local, local)) {
      return null;
    }
    final remoteRecords = remoteSnapshot.rows.map((row) {
      final json = jsonDecode(row.data) as Map<String, dynamic>;
      json['id'] = row.id;
      return store.modeling(json);
    }).toList(growable: false);

    // Store.synchronize has a bounded wait and can return its previous result
    // while a slow queued sync is still loading records. Briefly allow that
    // reload to finish, and never cache this remote version unless every
    // authoritative ID is present locally. Otherwise a premature empty alias
    // map could suppress the retry that repairs the duplicate choices.
    final remoteIDs = remoteRecords.map((record) => record.id).toSet();
    var authoritativeRowsAreLocal = remoteIDs.every(store.docs.containsKey);
    for (var attempt = 0;
        !authoritativeRowsAreLocal && attempt < 20;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!identical(store.remote, remote) || !identical(store.local, local)) {
        return null;
      }
      authoritativeRowsAreLocal = remoteIDs.every(store.docs.containsKey);
    }
    if (!authoritativeRowsAreLocal) return null;

    final deferred = await local.getDeferred();
    if (!identical(store.remote, remote) || !identical(store.local, local)) {
      return null;
    }
    final aliases = buildCatalogueAliasMap<T>(
      localRecords: store.docs.values,
      remoteRecords: remoteRecords,
      stableIdentity: stableIdentity,
      deferredRecordIDs: deferred.keys.toSet(),
    );
    return _AuthoritativeCatalogueSnapshot(
      remote: remote,
      version:
          remoteSnapshot.version == 0 ? remoteVersion : remoteSnapshot.version,
      aliases: aliases,
    );
  } catch (error, stackTrace) {
    // Catalogue reconciliation is a defensive cache repair. A transient
    // failure must not turn a successful ordinary sync into a failed login.
    logger(
      'Therapy catalogue cache reconciliation skipped: $error',
      stackTrace,
      1,
    );
    return null;
  }
}

void _syncStart() {
  networkActions.isSyncing(networkActions.isSyncing() + 1);
}

void _syncEnd() {
  networkActions.isSyncing(networkActions.isSyncing() - 1);
}

void _activateStore(
  Store store,
  String storeName, {
  Future<void> Function()? onLocalDemoActivated,
  void Function()? onPersistenceSessionActivated,
}) {
  onLogoutCallbacks.add(store.endSession);
  login.activators[storeName] = () async {
    await store.loaded;
    await store.deactivatePersistenceSession();
    await store.local?.dispose();
    onPersistenceSessionActivated?.call();
    store.local = SaveLocal(name: storeName, uniqueId: simpleHash(login.url));
    await store.deleteMemoryAndLoadFromPersistence();
    if (!launch.isDemo) {
      store.remote = SaveRemote(
        pbInstance: login.pb!,
        storeName: storeName,
        onOnlineStatusChange: (current) {
          if (network.isOnline() != current) network.isOnline(current);
        },
      );
    }
    if (launch.isLocalDemo && onLocalDemoActivated != null) {
      await onLocalDemoActivated();
    }
    return () async {
      loginCtrl.loadingIndicator('Synchronizing therapy catalogue');
      await store.synchronize();
      networkActions.syncCallbacks[storeName] = store.synchronize;
      if (store.remote != null) {
        networkActions.reconnectCallbacks[storeName] =
            store.remote!.checkOnline;
      }
      network.onOnline[storeName] = store.synchronize;
      network.onOffline[storeName] = store.cancelRealtimeSub;
    };
  };
}

final therapyGroups = TherapyGroups();
final procedureCatalog = ProcedureCatalog();
