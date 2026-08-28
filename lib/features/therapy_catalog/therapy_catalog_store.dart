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

import 'procedure_catalog_model.dart';
import 'procedure_handling_classifier.dart';
import 'therapy_group_model.dart';

class TherapyGroups extends Store<TherapyGroup> {
  TherapyGroups()
      : super(
          modeling: TherapyGroup.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: _syncStart,
          onSyncEnd: _syncEnd,
        );

  List<TherapyGroup> get ordered {
    final result = present.values.toList();
    result.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      return order != 0 ? order : a.title.compareTo(b.title);
    });
    return List.unmodifiable(result);
  }

  @override
  void init() {
    super.init();
    _activateStore(this, 'therapy_groups');
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

  void _clearCache([_]) => _byGroup = null;

  Map<String, List<ProcedureCatalogItem>> get byGroup {
    return _byGroup ??= _buildByGroup();
  }

  Map<String, List<ProcedureCatalogItem>> _buildByGroup() {
    final result = <String, List<ProcedureCatalogItem>>{};
    for (final item in present.values) {
      result.putIfAbsent(item.therapyGroupID, () => []).add(item);
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
    return item.odontogramOverlay ??
        inferOdontogramOverlay(
          procedureName: item.title,
          groupName: therapyGroups.get(item.therapyGroupID)?.title ?? '',
          targetScope: handlingDecision(item).mode.targetScope,
        );
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
    _activateStore(this, 'procedure_catalog');
  }
}

void _syncStart() {
  networkActions.isSyncing(networkActions.isSyncing() + 1);
}

void _syncEnd() {
  networkActions.isSyncing(networkActions.isSyncing() - 1);
}

void _activateStore(Store store, String storeName) {
  onLogoutCallbacks.add(store.endSession);
  login.activators[storeName] = () async {
    await store.loaded;
    await store.deactivatePersistenceSession();
    await store.local?.dispose();
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
