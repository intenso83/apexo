import 'package:apexo/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency picker offers EUR first and retains common legacy codes', () {
    expect(supportedCurrencyCodes.first, 'EUR');
    expect(supportedCurrencyCodes, containsAll(<String>['USD', 'IQD']));
    expect(
        supportedCurrencyCodes.toSet().length, supportedCurrencyCodes.length);
  });
}
