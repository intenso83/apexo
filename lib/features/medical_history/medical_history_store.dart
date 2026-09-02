import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

import 'medical_history_model.dart';

const medicalHistoryStoreName = 'medical_history_revisions';

class MedicalHistoryRevisions extends Store<MedicalHistoryRevision> {
  MedicalHistoryRevisions()
      : super(
          modeling: MedicalHistoryRevision.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  Map<String, List<MedicalHistoryRevision>>? _byPatient;

  void _clearCache([_]) => _byPatient = null;

  Map<String, List<MedicalHistoryRevision>> get byPatient =>
      _byPatient ??= _buildByPatient();

  List<MedicalHistoryRevision> forPatient(String patientID) =>
      List.unmodifiable(byPatient[patientID] ?? const []);

  MedicalHistoryRevision? latestForPatient(String patientID) {
    final revisions = forPatient(patientID);
    return revisions.isEmpty ? null : revisions.first;
  }

  /// Adds a new snapshot and refuses accidental overwrites of an existing ID.
  void addRevision(MedicalHistoryRevision revision) {
    if (has(revision.id)) {
      throw StateError(
        'Medical-history revisions are immutable; create a new revision.',
      );
    }
    super.set(revision);
    _clearCache();
  }

  Map<String, List<MedicalHistoryRevision>> _buildByPatient() {
    final result = <String, List<MedicalHistoryRevision>>{};
    for (final revision in present.values) {
      result.putIfAbsent(revision.patientID, () => []).add(revision);
    }
    for (final revisions in result.values) {
      revisions.sort((a, b) {
        final revisionOrder = b.revisionNumber.compareTo(a.revisionNumber);
        if (revisionOrder != 0) return revisionOrder;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return result;
  }

  @override
  void set(MedicalHistoryRevision item) {
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<MedicalHistoryRevision> items) {
    super.setAll(items);
    _clearCache();
  }

  @override
  void init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    observableMap.observe(_clearCache);
    login.activators[medicalHistoryStoreName] = () async {
      await loaded;
      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(
        name: medicalHistoryStoreName,
        uniqueId: simpleHash(login.url),
      );
      await deleteMemoryAndLoadFromPersistence();
      if (!launch.isDemo) {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: medicalHistoryStoreName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) network.isOnline(current);
          },
        );
      }
      return () async {
        loginCtrl.loadingIndicator('Synchronizing medical history');
        await synchronize();
        networkActions.syncCallbacks[medicalHistoryStoreName] = synchronize;
        networkActions.reconnectCallbacks[medicalHistoryStoreName] =
            remote!.checkOnline;
        network.onOnline[medicalHistoryStoreName] = synchronize;
        network.onOffline[medicalHistoryStoreName] = cancelRealtimeSub;
      };
    };
  }
}

final medicalHistoryRevisions = MedicalHistoryRevisions();
