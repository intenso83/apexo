import 'package:apexo/app/routes.dart';
import 'package:apexo/services/launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    launch.exitLocalDemo();
    routes.reset();
  });

  tearDown(() {
    launch.exitLocalDemo();
    routes.reset();
  });

  test('ordinary Apexo sessions continue to start on the dashboard', () {
    expect(routes.allRoutes.first.identifier, 'dashboard');
    expect(
      routes.allRoutes.where((route) => route.identifier == 'clinicalBeta'),
      isEmpty,
    );
  });

  test('local Demo starts on the beta hub and exposes the catalogue', () {
    launch.enterLocalDemo();
    routes.reset();

    expect(routes.currentRoute.identifier, 'clinicalBeta');
    expect(
      routes.allRoutes.any((route) => route.identifier == 'therapyCatalogue'),
      isTrue,
    );
  });
}
