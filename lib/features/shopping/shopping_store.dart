import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/features/shopping/shopping_item_model.dart';
import 'package:apexo/features/shopping/shopping_id_migration.dart';
import 'package:apexo/features/shopping/shopping_template.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

const _storeName = 'shopping_list';

class ShoppingListStore extends Store<ShoppingItem> {
  ShoppingListStore()
      : super(
          modeling: ShoppingItem.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  List<ShoppingItem> get categories {
    final result = present.values.where((item) => item.isCategory).toList();
    result.sort(_ordered);
    return List.unmodifiable(result);
  }

  List<ShoppingItem> get materials {
    final result = present.values.where((item) => !item.isCategory).toList();
    result.sort((a, b) {
      final category = categoryTitle(a.categoryID)
          .toLowerCase()
          .compareTo(categoryTitle(b.categoryID).toLowerCase());
      return category != 0 ? category : _ordered(a, b);
    });
    return List.unmodifiable(result);
  }

  List<ShoppingItem> get urgent => materials
      .where((item) => item.needed && item.priority == ShoppingPriority.urgent)
      .toList(growable: false);

  List<ShoppingItem> forCategory(String categoryID) => materials
      .where((item) => item.categoryID == categoryID)
      .toList(growable: false);

  String categoryTitle(String categoryID) =>
      get(categoryID)?.title ?? categoryID;

  double nextOrder(String categoryID) {
    final items = forCategory(categoryID);
    if (items.isEmpty) return 0;
    return items
            .map((item) => item.displayOrder)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  int _ordered(ShoppingItem a, ShoppingItem b) {
    final order = a.displayOrder.compareTo(b.displayOrder);
    return order != 0
        ? order
        : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  void init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    login.activators[_storeName] = () async {
      await loaded;
      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();
      await _migrateInvalidRecordIds();
      if (!launch.isDemo) {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: _storeName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) network.isOnline(current);
          },
        );
      }
      if (launch.isDemo && docs.isEmpty) setAll(buildShoppingTemplate());
      return () async {
        loginCtrl.loadingIndicator('Synchronizing shopping list');
        await synchronize();
        if (docs.isEmpty) setAll(buildShoppingTemplate());
        networkActions.syncCallbacks[_storeName] = synchronize;
        if (remote != null) {
          networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;
        }
        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  Future<void> _migrateInvalidRecordIds() async {
    final persistence = local;
    if (persistence == null) return;

    final migration = planShoppingIdMigration(
      records: await persistence.getAll(),
      deferred: await persistence.getDeferred(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (!migration.isNeeded) return;

    // Write replacements before removing the invalid keys so an interrupted
    // migration cannot discard the user's shopping-list customizations.
    await persistence.put(migration.recordsToWrite);
    await persistence.putDeferred(migration.deferred);
    await persistence.delete(migration.recordIdsToDelete);
    deferredPresent = migration.deferred.isNotEmpty;
    await deleteMemoryAndLoadFromPersistence();
  }
}

final shoppingList = ShoppingListStore();
