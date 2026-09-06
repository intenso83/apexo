import 'package:apexo/features/settings/settings_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late int originalLocale;
  late String originalDateFormat;

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  setUp(() {
    originalLocale = localSettings.selectedLocale;
    originalDateFormat = localSettings.dateFormat;
    localSettings.selectedLocale = 0;
    localSettings.dateFormat = 'dd/MM/yyyy';
  });

  tearDown(() {
    localSettings.selectedLocale = originalLocale;
    localSettings.dateFormat = originalDateFormat;
  });

  test('appointment time helpers always use a zero-padded 24-hour clock', () {
    final appointmentTime = DateTime(2026, 9, 6, 23, 7);

    expect(DF.clock(appointmentTime), '23:07');
    expect(DF.time(appointmentTime), '🕒 23:07');
    expect(DF.full(appointmentTime), contains('23:07'));
    expect(DF.fullCompact(appointmentTime), contains('23:07'));
    expect(DF.full(appointmentTime).toLowerCase(), isNot(contains('pm')));
  });

  test('midnight is represented as 00:00', () {
    expect(DF.clock(DateTime(2026, 9, 7)), '00:00');
  });
}
