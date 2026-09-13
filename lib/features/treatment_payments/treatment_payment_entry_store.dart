import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

import 'treatment_bill_model.dart';

const _storeName = 'treatment_payment_entries';

class TreatmentPaymentEntries extends Store<TreatmentPaymentEntry> {
  TreatmentPaymentEntries()
      : super(
          modeling: TreatmentPaymentEntry.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () =>
              networkActions.isSyncing(networkActions.isSyncing() + 1),
          onSyncEnd: () =>
              networkActions.isSyncing(networkActions.isSyncing() - 1),
        );

  List<TreatmentPaymentEntry> forEvent(String odontogramEventID) =>
      List.unmodifiable(
        present.values
            .where((entry) => entry.odontogramEventID == odontogramEventID)
            .toList()
          ..sort((a, b) {
            final sequence = a.sequence.compareTo(b.sequence);
            if (sequence != 0) return sequence;
            final date = a.occurredAt.compareTo(b.occurredAt);
            return date == 0 ? a.id.compareTo(b.id) : date;
          }),
      );

  @override
  void set(TreatmentPaymentEntry item) {
    final errors = item.validationErrors();
    if (errors.isNotEmpty) {
      throw ArgumentError(
          'Invalid treatment payment entry fields: ${errors.join(', ')}');
    }
    if (has(item.id)) {
      throw StateError('Ledger entries are append-only.');
    }
    super.set(item);
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
      if (!launch.isDemo) {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: _storeName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) network.isOnline(current);
          },
        );
      }
      return () async {
        loginCtrl.loadingIndicator('Synchronizing treatment payments');
        await synchronize();
        networkActions.syncCallbacks[_storeName] = synchronize;
        if (remote != null) {
          networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;
        }
        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }
}

final treatmentPaymentEntries = TreatmentPaymentEntries();
