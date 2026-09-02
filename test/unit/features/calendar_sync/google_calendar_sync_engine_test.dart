import 'package:apexo/features/calendar_sync/google_calendar_gateway.dart';
import 'package:apexo/features/calendar_sync/google_calendar_mapper.dart';
import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
import 'package:apexo/features/calendar_sync/google_calendar_sync_engine.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/google_calendar_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/model_factory.dart';

void main() {
  const preferences = GoogleCalendarSyncPreferences(
    enabled: true,
    calendarId: 'primary',
    clinicId: 'clinic-1',
    accountId: 'user-a',
  );
  final fixedNow = DateTime.utc(2026, 8, 31, 8);

  test('creates a private managed event and saves sync metadata', () async {
    final gateway = _FakeGateway();
    final appointment = testAppointment(
      id: 'new-appointment',
      date: DateTime.utc(2026, 9, 1, 8),
    );
    final saved = <Appointment>[];

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferences,
      state: const GoogleCalendarSyncState(),
      saveAppointment: (value) async => saved.add(value),
      patientName: (_) => 'Private Patient',
    );

    expect(result.created, 1);
    expect(gateway.inserted.single.summary, 'Dental appointment');
    expect(gateway.inserted.single.toApiJson().toString(),
        isNot(contains('Private Patient')));
    final link = appointment.googleCalendarLinkFor(preferences.accountId);
    expect(link.eventId, isNotEmpty);
    expect(link.syncFingerprint, isNotEmpty);
    expect(saved, hasLength(1));
  });

  test('pulls a remote-only time change in two-way mode', () async {
    final mapper = GoogleCalendarMapper();
    final appointment = testAppointment(
      id: 'remote-change',
      date: DateTime.utc(2026, 9, 1, 8),
      duration: 30,
    );
    final original = mapper.fromAppointment(
      appointment: appointment,
      preferences: preferences,
      patientName: '',
    );
    appointment.setGoogleCalendarLink(
      preferences.accountId,
      GoogleCalendarAppointmentLink(
        eventId: original.id,
        calendarId: 'primary',
        etag: 'etag-old',
        syncFingerprint: mapper.fingerprint(
          appointment,
          summary: original.summary,
        ),
      ),
    );
    final remote = GoogleCalendarEvent(
      id: original.id,
      status: 'confirmed',
      summary: original.summary,
      description: original.description,
      start: DateTime.utc(2026, 9, 1, 10),
      end: DateTime.utc(2026, 9, 1, 10, 45),
      etag: 'etag-new',
      privateProperties: original.privateProperties,
    );
    final gateway = _FakeGateway(events: [remote]);

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      mapper: mapper,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferences,
      state: const GoogleCalendarSyncState(syncToken: 'token'),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    expect(result.updatedInApexo, 1);
    expect(appointment.date.toUtc(), DateTime.utc(2026, 9, 1, 10));
    expect(appointment.duration, 45);
    expect(
      appointment.googleCalendarLinkFor(preferences.accountId).etag,
      'etag-new',
    );
  });

  test('reports a conflict instead of overwriting when both sides changed',
      () async {
    final mapper = GoogleCalendarMapper();
    final appointment = testAppointment(
      id: 'conflict',
      date: DateTime.utc(2026, 9, 1, 8),
      duration: 30,
    );
    final originalFingerprint = mapper.fingerprint(
      appointment,
      summary: GoogleCalendarMapper.genericSummary,
    );
    final eventId = mapper.eventIdFor(
      clinicId: preferences.clinicId,
      accountId: preferences.accountId,
      appointmentId: appointment.id,
    );
    appointment.setGoogleCalendarLink(
      preferences.accountId,
      GoogleCalendarAppointmentLink(
        eventId: eventId,
        calendarId: 'primary',
        etag: 'etag-old',
        syncFingerprint: originalFingerprint,
      ),
    );
    appointment.date = DateTime.utc(2026, 9, 1, 9); // local edit
    final remote = GoogleCalendarEvent(
      id: eventId,
      status: 'confirmed',
      summary: 'Dental appointment',
      description: '',
      start: DateTime.utc(2026, 9, 1, 11),
      end: DateTime.utc(2026, 9, 1, 11, 30),
      etag: 'etag-new',
      privateProperties: {
        'apexoManaged': '1',
        'apexoAppointmentId': appointment.id,
        'apexoClinicId': preferences.clinicId,
        'apexoAccountId': preferences.accountId,
      },
    );
    final gateway = _FakeGateway(events: [remote]);

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      mapper: mapper,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferences,
      state: const GoogleCalendarSyncState(syncToken: 'token'),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    expect(result.issues.single.type, GoogleCalendarSyncIssueType.conflict);
    expect(appointment.date.toUtc(), DateTime.utc(2026, 9, 1, 9));
    expect(gateway.patched, isEmpty);
  });

  test('a rejected incremental token triggers a full resync', () async {
    final gateway = _FakeGateway(invalidateFirstSyncToken: true);

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      now: () => fixedNow,
    ).sync(
      appointments: const [],
      preferences: preferences,
      state: const GoogleCalendarSyncState(syncToken: 'expired-token'),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    expect(result.performedFullResync, isTrue);
    expect(gateway.receivedSyncTokens, ['expired-token', null]);
  });

  test('remote deletion never silently deletes the Apexo appointment',
      () async {
    final mapper = GoogleCalendarMapper();
    final appointment = testAppointment(
      id: 'remote-deleted',
      date: DateTime.utc(2026, 9, 1, 8),
    );
    final eventId = mapper.eventIdFor(
      clinicId: preferences.clinicId,
      accountId: preferences.accountId,
      appointmentId: appointment.id,
    );
    appointment.setGoogleCalendarLink(
      preferences.accountId,
      GoogleCalendarAppointmentLink(
        eventId: eventId,
        calendarId: 'primary',
        etag: 'etag-old',
        syncFingerprint: mapper.fingerprint(
          appointment,
          summary: GoogleCalendarMapper.genericSummary,
        ),
      ),
    );
    final gateway = _FakeGateway(events: [
      GoogleCalendarEvent(
        id: eventId,
        status: 'cancelled',
        summary: '',
        description: '',
        start: null,
        end: null,
        etag: 'etag-new',
        privateProperties: {
          'apexoManaged': '1',
          'apexoAppointmentId': appointment.id,
          'apexoClinicId': preferences.clinicId,
          'apexoAccountId': preferences.accountId,
        },
      ),
    ]);

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      mapper: mapper,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferences,
      state: const GoogleCalendarSyncState(syncToken: 'token'),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    expect(
        result.issues.single.type, GoogleCalendarSyncIssueType.remoteDeletion);
    expect(appointment.archived, isNot(true));
  });

  test('ignores unrelated events returned by an incremental sync', () async {
    final gateway = _FakeGateway(events: [
      GoogleCalendarEvent(
        id: 'personal-event',
        status: 'confirmed',
        summary: 'Personal appointment',
        description: '',
        start: DateTime.utc(2026, 9, 1, 8),
        end: DateTime.utc(2026, 9, 1, 9),
      ),
    ]);

    final result = await GoogleCalendarSyncEngine(
      gateway: gateway,
      now: () => fixedNow,
    ).sync(
      appointments: const [],
      preferences: preferences,
      state: const GoogleCalendarSyncState(syncToken: 'token'),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    expect(result.issues, isEmpty);
  });

  test('keeps separate event links for separate Apexo Google accounts',
      () async {
    final appointment = testAppointment(
      id: 'shared-appointment',
      date: DateTime.utc(2026, 9, 1, 8),
    );
    final gatewayA = _FakeGateway();
    final gatewayB = _FakeGateway();
    const preferencesB = GoogleCalendarSyncPreferences(
      enabled: true,
      calendarId: 'primary',
      clinicId: 'clinic-1',
      accountId: 'user-b',
    );

    await GoogleCalendarSyncEngine(
      gateway: gatewayA,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferences,
      state: const GoogleCalendarSyncState(),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );
    await GoogleCalendarSyncEngine(
      gateway: gatewayB,
      now: () => fixedNow,
    ).sync(
      appointments: [appointment],
      preferences: preferencesB,
      state: const GoogleCalendarSyncState(),
      saveAppointment: (_) async {},
      patientName: (_) => '',
    );

    final linkA = appointment.googleCalendarLinkFor('user-a');
    final linkB = appointment.googleCalendarLinkFor('user-b');
    expect(linkA.isLinked, isTrue);
    expect(linkB.isLinked, isTrue);
    expect(linkA.eventId, isNot(linkB.eventId));
    expect(appointment.googleCalendarLinks.keys,
        containsAll(['user-a', 'user-b']));
  });
}

class _FakeGateway implements GoogleCalendarGateway {
  final List<GoogleCalendarEvent> events;
  final bool invalidateFirstSyncToken;
  final List<GoogleCalendarEvent> inserted = [];
  final List<GoogleCalendarEvent> patched = [];
  final List<String> deleted = [];
  final List<String?> receivedSyncTokens = [];
  bool _invalidated = false;

  _FakeGateway({
    this.events = const [],
    this.invalidateFirstSyncToken = false,
  });

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
    receivedSyncTokens.add(syncToken);
    if (invalidateFirstSyncToken && !_invalidated && syncToken != null) {
      _invalidated = true;
      throw const GoogleCalendarSyncTokenInvalid();
    }
    return GoogleCalendarEventPage(
      events: events,
      nextSyncToken: 'next-token',
    );
  }

  @override
  Future<GoogleCalendarEvent> insertEvent({
    required String calendarId,
    required GoogleCalendarEvent event,
  }) async {
    inserted.add(event);
    return _withServerMetadata(event, 'inserted');
  }

  @override
  Future<GoogleCalendarEvent> patchEvent({
    required String calendarId,
    required String eventId,
    required GoogleCalendarEvent event,
  }) async {
    patched.add(event);
    return _withServerMetadata(event, 'patched');
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    deleted.add(eventId);
  }

  GoogleCalendarEvent _withServerMetadata(
    GoogleCalendarEvent event,
    String etag,
  ) =>
      GoogleCalendarEvent(
        id: event.id,
        status: event.status,
        summary: event.summary,
        description: event.description,
        start: event.start,
        end: event.end,
        etag: etag,
        updatedAt: DateTime.utc(2026, 8, 31, 8),
        htmlLink: 'https://calendar.google.com/event/${event.id}',
        transparency: event.transparency,
        privateProperties: event.privateProperties,
      );
}
