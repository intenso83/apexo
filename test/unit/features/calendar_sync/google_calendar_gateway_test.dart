import 'dart:convert';

import 'package:apexo/features/calendar_sync/google_calendar_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('initial list filters to the clinic private extended property',
      () async {
    late Uri requested;
    final gateway = GoogleCalendarHttpGateway(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({'items': [], 'nextSyncToken': 'n'}),
          200,
        );
      }),
      accessTokenProvider: () async => 'token',
    );

    await gateway.listEvents(
      calendarId: 'primary',
      clinicId: 'clinic-1',
      timeMin: DateTime.utc(2026, 1, 1),
      timeMax: DateTime.utc(2027, 1, 1),
    );

    expect(
      requested.queryParameters['privateExtendedProperty'],
      'apexoClinicId=clinic-1',
    );
    expect(requested.queryParameters, isNot(contains('syncToken')));
  });

  test('incremental list omits filters forbidden with syncToken', () async {
    late Uri requested;
    final gateway = GoogleCalendarHttpGateway(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({'items': [], 'nextSyncToken': 'n'}),
          200,
        );
      }),
      accessTokenProvider: () async => 'token',
    );

    await gateway.listEvents(
      calendarId: 'primary',
      clinicId: 'clinic-1',
      syncToken: 'previous-token',
      timeMin: DateTime.utc(2026, 1, 1),
      timeMax: DateTime.utc(2027, 1, 1),
    );

    expect(requested.queryParameters['syncToken'], 'previous-token');
    expect(
      requested.queryParameters,
      isNot(contains('privateExtendedProperty')),
    );
    expect(requested.queryParameters, isNot(contains('timeMin')));
    expect(requested.queryParameters, isNot(contains('timeMax')));
  });

  test('busy-block listing deliberately omits the Apexo ownership filter',
      () async {
    late Uri requested;
    final gateway = GoogleCalendarHttpGateway(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({'items': [], 'nextSyncToken': 'n'}),
          200,
        );
      }),
      accessTokenProvider: () async => 'token',
    );

    await gateway.listEvents(
      calendarId: 'primary',
      clinicId: 'clinic-1',
      managedOnly: false,
      timeMin: DateTime.utc(2026, 1, 1),
      timeMax: DateTime.utc(2027, 1, 1),
    );

    expect(
      requested.queryParameters,
      isNot(contains('privateExtendedProperty')),
    );
    expect(requested.queryParameters, contains('timeMin'));
    expect(requested.queryParameters, contains('timeMax'));
  });
}
