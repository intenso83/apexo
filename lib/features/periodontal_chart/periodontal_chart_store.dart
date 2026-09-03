import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/save_remote.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/features/network_actions/network_actions_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/utils/hash.dart';

import 'periodontal_chart_model.dart';

const periodontalChartStoreName = 'periodontal_charts';

class PeriodontalCharts extends Store<PeriodontalChart> {
  PeriodontalCharts()
      : super(
          modeling: PeriodontalChart.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  Map<String, List<PeriodontalChart>>? _byPatient;

  void _clearCache([_]) => _byPatient = null;

  List<PeriodontalChart> forPatient(String patientID) => List.unmodifiable(
      (_byPatient ??= _buildByPatient())[patientID] ?? const []);

  PeriodontalChart? latestForPatient(String patientID) {
    final charts = forPatient(patientID);
    return charts.isEmpty ? null : charts.first;
  }

  void addChart(PeriodontalChart chart) {
    if (has(chart.id)) {
      throw StateError('Periodontal charts are immutable; create a new exam.');
    }
    super.set(chart);
    _clearCache();
  }

  Map<String, List<PeriodontalChart>> _buildByPatient() {
    final result = <String, List<PeriodontalChart>>{};
    for (final chart in present.values) {
      result.putIfAbsent(chart.patientID, () => []).add(chart);
    }
    for (final charts in result.values) {
      charts.sort((a, b) {
        final byDate = b.recordedAt.compareTo(a.recordedAt);
        return byDate != 0
            ? byDate
            : b.revisionNumber.compareTo(a.revisionNumber);
      });
    }
    return result;
  }

  @override
  void set(PeriodontalChart item) {
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<PeriodontalChart> items) {
    super.setAll(items);
    _clearCache();
  }

  @override
  void init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    observableMap.observe(_clearCache);
    login.activators[periodontalChartStoreName] = () async {
      await loaded;
      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(
        name: periodontalChartStoreName,
        uniqueId: simpleHash(login.url),
      );
      await deleteMemoryAndLoadFromPersistence();
      if (!launch.isDemo) {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: periodontalChartStoreName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) network.isOnline(current);
          },
        );
      }
      return () async {
        loginCtrl.loadingIndicator('Synchronizing periodontal charts');
        await synchronize();
        networkActions.syncCallbacks[periodontalChartStoreName] = synchronize;
        networkActions.reconnectCallbacks[periodontalChartStoreName] =
            remote!.checkOnline;
        network.onOnline[periodontalChartStoreName] = synchronize;
        network.onOffline[periodontalChartStoreName] = cancelRealtimeSub;
      };
    };
  }
}

final periodontalCharts = PeriodontalCharts();
