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
        .where((item) => !item.hidden && requiresLaboratory(item))
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
    _activateStore(
      this,
      'procedure_catalog',
      onLocalDemoActivated: () async {
        if (therapyGroups.present.isNotEmpty || present.isNotEmpty) return;
        final demo = await loadDemoTherapyCatalogue();
        therapyGroups.setAll(demo.groups);
        setAll(demo.procedures);
      },
    );
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
}) {
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
