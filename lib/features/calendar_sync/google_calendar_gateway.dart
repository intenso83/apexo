import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_calendar_models.dart';

abstract class GoogleCalendarGateway {
  Future<GoogleCalendarEventPage> listEvents({
    required String calendarId,
    required String clinicId,
    bool managedOnly = true,
    String? syncToken,
    String? pageToken,
    DateTime? timeMin,
    DateTime? timeMax,
  });

  Future<GoogleCalendarEvent> insertEvent({
    required String calendarId,
    required GoogleCalendarEvent event,
  });

  Future<GoogleCalendarEvent> patchEvent({
    required String calendarId,
    required String eventId,
    required GoogleCalendarEvent event,
  });

  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  });
}

typedef GoogleAccessTokenProvider = Future<String> Function();

/// Calendar API transport. OAuth is intentionally injected so tokens can live
/// in platform-secure storage instead of source code or PocketBase.
class GoogleCalendarHttpGateway implements GoogleCalendarGateway {
  final http.Client client;
  final GoogleAccessTokenProvider accessTokenProvider;

  GoogleCalendarHttpGateway({
    required this.client,
    required this.accessTokenProvider,
  });

  static const _base = 'https://www.googleapis.com/calendar/v3';

  @override
  Future<GoogleCalendarEventPage> listEvents({
    required String calendarId,
    required String clinicId,
    bool managedOnly = true,
    String? syncToken,
    String? pageToken,
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    final query = <String, String>{
      'showDeleted': 'true',
      'singleEvents': 'true',
      'maxResults': '2500',
      if (managedOnly && (syncToken == null || syncToken.isEmpty))
        'privateExtendedProperty': 'apexoClinicId=$clinicId',
      if (syncToken != null && syncToken.isNotEmpty) 'syncToken': syncToken,
      if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      if ((syncToken == null || syncToken.isEmpty) && timeMin != null)
        'timeMin': timeMin.toUtc().toIso8601String(),
      if ((syncToken == null || syncToken.isEmpty) && timeMax != null)
        'timeMax': timeMax.toUtc().toIso8601String(),
    };
    final response = await client.get(
      Uri.parse(
        '$_base/calendars/${Uri.encodeComponent(calendarId)}/events',
      ).replace(queryParameters: query),
      headers: await _headers(),
    );
    if (response.statusCode == 410) {
      throw const GoogleCalendarSyncTokenInvalid();
    }
    _expectSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GoogleCalendarEvent.fromApiJson)
        .toList();
    return GoogleCalendarEventPage(
      events: items,
      nextPageToken: body['nextPageToken']?.toString(),
      nextSyncToken: body['nextSyncToken']?.toString(),
    );
  }

  @override
  Future<GoogleCalendarEvent> insertEvent({
    required String calendarId,
    required GoogleCalendarEvent event,
  }) async {
    final response = await client.post(
      Uri.parse(
        '$_base/calendars/${Uri.encodeComponent(calendarId)}/events',
      ),
      headers: await _headers(json: true),
      body: jsonEncode(event.toApiJson()),
    );
    _expectSuccess(response);
    return GoogleCalendarEvent.fromApiJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<GoogleCalendarEvent> patchEvent({
    required String calendarId,
    required String eventId,
    required GoogleCalendarEvent event,
  }) async {
    final response = await client.patch(
      Uri.parse(
        '$_base/calendars/${Uri.encodeComponent(calendarId)}/events/'
        '${Uri.encodeComponent(eventId)}',
      ),
      headers: await _headers(json: true),
      body: jsonEncode(event.toApiJson()..remove('id')),
    );
    _expectSuccess(response);
    return GoogleCalendarEvent.fromApiJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    final response = await client.delete(
      Uri.parse(
        '$_base/calendars/${Uri.encodeComponent(calendarId)}/events/'
        '${Uri.encodeComponent(eventId)}',
      ),
      headers: await _headers(),
    );
    if (response.statusCode == 404 || response.statusCode == 410) return;
    _expectSuccess(response);
  }

  Future<Map<String, String>> _headers({bool json = false}) async => {
        'Authorization': 'Bearer ${await accessTokenProvider()}',
        if (json) 'Content-Type': 'application/json; charset=utf-8',
      };

  void _expectSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw GoogleCalendarApiException(
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }
}

class GoogleCalendarApiException implements Exception {
  final int statusCode;
  final String responseBody;

  const GoogleCalendarApiException({
    required this.statusCode,
    required this.responseBody,
  });

  @override
  String toString() => 'Google Calendar API error $statusCode: $responseBody';
}
