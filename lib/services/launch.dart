import 'package:apexo/core/observable.dart';

enum Open { login, staff, patient }

class _Launch {
  final bool _hostedDemo = Uri.base.host == "demo.apexo.app";
  bool _localDemo = false;
  final dialogShown = ObservableState(false);
  final isFirstLaunch = ObservableState(false);
  final open = ObservableState(Open.login);
  final paneIsOverlaying = ObservableState(false);
  double layoutWidth = 0;

  bool get isDemo => _hostedDemo || _localDemo;
  bool get isLocalDemo => _localDemo;

  void enterLocalDemo() => _localDemo = true;
  void exitLocalDemo() => _localDemo = false;
}

final launch = _Launch();
