import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

import 'treatment_history_model.dart';

const _storeName = 'treatment_history';

class TreatmentHistory extends Store<TreatmentHistoryEntry> {
  TreatmentHistory()
      : super(
          modeling: TreatmentHistoryEntry.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  Map<String, List<TreatmentHistoryEntry>>? _byPatient;

  void _clearCache([_]) => _byPatient = null;

  Map<String, List<TreatmentHistoryEntry>> get byPatient {
    return _byPatient ??= _buildByPatient();
  }

  Map<String, List<TreatmentHistoryEntry>> _buildByPatient() {
    final result = <String, List<TreatmentHistoryEntry>>{};
    for (final entry in present.values) {
      result.putIfAbsent(entry.patientID, () => []).add(entry);
    }
    for (final entries in result.values) {
      entries.sort((a, b) {
        if (a.date == null && b.date == null) {
          return a.treatmentName.compareTo(b.treatmentName);
        }
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
    }
    return result;
  }

  List<TreatmentHistoryEntry> forPatient(String patientID) =>
      List.unmodifiable(byPatient[patientID] ?? const []);

  @override
  void set(TreatmentHistoryEntry item) {
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<TreatmentHistoryEntry> items) {
    super.setAll(items);
    _clearCache();
  }

  @override
  void init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    observableMap.observe(_clearCache);
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
        loginCtrl.loadingIndicator('Synchronizing treatment history');
        await synchronize();
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;
        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }
}

final treatmentHistory = TreatmentHistory();
