import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

import 'odontogram_event_model.dart';

const _storeName = 'odontogram_events';

class OdontogramEvents extends Store<OdontogramEvent> {
  OdontogramEvents()
      : super(
          modeling: OdontogramEvent.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () =>
              networkActions.isSyncing(networkActions.isSyncing() + 1),
          onSyncEnd: () =>
              networkActions.isSyncing(networkActions.isSyncing() - 1),
        );

  Map<String, List<OdontogramEvent>>? _byPatient;

  void _clearCache([_]) => _byPatient = null;

  Map<String, List<OdontogramEvent>> get byPatient {
    return _byPatient ??= _buildByPatient();
  }

  Map<String, List<OdontogramEvent>> _buildByPatient() {
    final result = <String, List<OdontogramEvent>>{};
    for (final event in present.values) {
      result.putIfAbsent(event.patientID, () => []).add(event);
    }
    for (final events in result.values) {
      events.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }
    return result;
  }

  List<OdontogramEvent> forPatient(String patientID) =>
      List.unmodifiable(byPatient[patientID] ?? const []);

  List<OdontogramEvent> forTooth(String patientID, int fdi) =>
      List.unmodifiable(
        forPatient(patientID).where((event) => event.toothFdi == fdi),
      );

  @override
  void set(OdontogramEvent item) {
    final errors = item.validationErrors();
    if (errors.isNotEmpty) {
      throw ArgumentError(
          'Invalid odontogram event fields: ${errors.join(', ')}');
    }
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<OdontogramEvent> items) {
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
        loginCtrl.loadingIndicator('Synchronizing odontogram');
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

final odontogramEvents = OdontogramEvents();
