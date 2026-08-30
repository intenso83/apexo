import 'package:apexo/core/save_local.dart';
import 'package:apexo/core/store.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/utils/hash.dart';

import 'treatment_plan_model.dart';

const _storeName = 'treatment_plans';

class TreatmentPlans extends Store<TreatmentPlan> {
  TreatmentPlans()
      : super(
          modeling: TreatmentPlan.fromJson,
          isDemo: launch.isDemo,
        );

  Map<String, List<TreatmentPlan>>? _byPatient;

  void _clearCache([_]) => _byPatient = null;

  Map<String, List<TreatmentPlan>> get byPatient =>
      _byPatient ??= _buildByPatient();

  Map<String, List<TreatmentPlan>> _buildByPatient() {
    final result = <String, List<TreatmentPlan>>{};
    for (final plan in present.values) {
      result.putIfAbsent(plan.patientID, () => []).add(plan);
    }
    for (final plans in result.values) {
      plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return result;
  }

  List<TreatmentPlan> forPatient(String patientID) =>
      List.unmodifiable(byPatient[patientID] ?? const []);

  @override
  void set(TreatmentPlan item) {
    item.updatedAt = DateTime.now();
    super.set(item);
    _clearCache();
  }

  @override
  void setAll(List<TreatmentPlan> items) {
    super.setAll(items);
    _clearCache();
  }

  @override
  void init() {
    super.init();
    observableMap.observe(_clearCache);
    onLogoutCallbacks.add(endSession);
    login.activators[_storeName] = () async {
      await loaded;
      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();

      // Treatment plans remain local-first until the matching server
      // collection and access rules are deployed. This prevents a prototype
      // from creating or mutating financial records remotely.
      remote = null;
      return () async {
        loginCtrl.loadingIndicator('Loading treatment plans');
        await loaded;
      };
    };
  }
}

final treatmentPlans = TreatmentPlans();
