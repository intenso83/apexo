import 'package:apexo/features/calendar_sync/google_calendar_mapper.dart';
import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/model_factory.dart';

void main() {
  const privatePreferences = GoogleCalendarSyncPreferences(
    enabled: true,
    calendarId: 'primary',
    clinicId: 'clinic-1',
  );

  test('event IDs are deterministic and valid Google base32hex IDs', () {
    final mapper = GoogleCalendarMapper();
    final first = mapper.eventIdFor(
      clinicId: 'clinic-1',
      appointmentId: 'appointment-1',
    );
    final second = mapper.eventIdFor(
      clinicId: 'clinic-1',
      appointmentId: 'appointment-1',
    );

    expect(first, second);
    expect(first, matches(RegExp(r'^[0-9a-v]+$')));
    expect(first.length, 38);
  });

  test('default mapping exports no patient identity or clinical information',
      () {
    final appointment = testAppointment(
      id: 'private-event',
      patientID: 'patient-1',
      preOpNotes: 'Private clinical note',
      price: 900,
      date: DateTime.utc(2026, 9, 1, 8),
      duration: 30,
    );
    final event = GoogleCalendarMapper().fromAppointment(
      appointment: appointment,
      preferences: privatePreferences,
      patientName: 'Patient Name',
    );
    final encoded = event.toApiJson().toString();

    expect(event.summary, GoogleCalendarMapper.genericSummary);
    expect(encoded, isNot(contains('Patient Name')));
    expect(encoded, isNot(contains('Private clinical note')));
    expect(encoded, isNot(contains('900')));
    expect(event.privateProperties['apexoAppointmentId'], 'private-event');
  });

  test('patient title requires explicit preference', () {
    const preferences = GoogleCalendarSyncPreferences(
      enabled: true,
      calendarId: 'primary',
      clinicId: 'clinic-1',
      titleMode: GoogleCalendarTitleMode.patientName,
    );
    final event = GoogleCalendarMapper().fromAppointment(
      appointment: testAppointment(id: 'named'),
      preferences: preferences,
      patientName: 'Jane Doe',
    );

    expect(event.summary, 'Jane Doe');
  });

  test('remote times update appointment start and duration', () {
    final appointment = testAppointment(
      id: 'remote-time',
      date: DateTime.utc(2026, 9, 1, 8),
      duration: 15,
    );
    final changed = GoogleCalendarMapper().applyRemoteTime(
      GoogleCalendarEvent(
        id: 'event',
        status: 'confirmed',
        summary: 'Dental appointment',
        description: '',
        start: DateTime.utc(2026, 9, 1, 10),
        end: DateTime.utc(2026, 9, 1, 10, 45),
      ),
      appointment,
    );

    expect(changed, isTrue);
    expect(appointment.date.toUtc(), DateTime.utc(2026, 9, 1, 10));
    expect(appointment.duration, 45);
  });
}
