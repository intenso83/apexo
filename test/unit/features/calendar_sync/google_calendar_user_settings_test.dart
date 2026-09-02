import 'package:apexo/features/calendar_sync/google_calendar_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user settings round-trip without OAuth token material', () {
    final lastSync = DateTime.utc(2026, 8, 31, 8, 30);
    final settings = GoogleCalendarUserSettings(
      syncEnabled: true,
      googleAccountEmail: 'dentist@gmail.com',
      credentialReference: 'secure:apexo-user-1',
      calendarId: 'clinic-calendar@group.calendar.google.com',
      direction: GoogleCalendarSyncDirection.apexoToGoogle,
      appointmentScope: GoogleCalendarAppointmentScope.allAppointments,
      titleMode: GoogleCalendarTitleMode.patientName,
      includePhone: false,
      includeMobile: true,
      includeEmail: false,
      includeAddress: true,
      syncToken: 'calendar-sync-token',
      lastSuccessfulSync: lastSync,
      lastError: 'none',
    );

    final json = settings.toJson();
    final restored = GoogleCalendarUserSettings.fromJson(json);

    expect(restored.isConnected, isTrue);
    expect(restored.googleAccountEmail, 'dentist@gmail.com');
    expect(restored.credentialReference, 'secure:apexo-user-1');
    expect(restored.calendarId, 'clinic-calendar@group.calendar.google.com');
    expect(restored.direction, GoogleCalendarSyncDirection.apexoToGoogle);
    expect(
      restored.appointmentScope,
      GoogleCalendarAppointmentScope.allAppointments,
    );
    expect(restored.titleMode, GoogleCalendarTitleMode.patientName);
    expect(restored.includePhone, isFalse);
    expect(restored.includeMobile, isTrue);
    expect(restored.includeEmail, isFalse);
    expect(restored.includeAddress, isTrue);
    expect(restored.syncToken, 'calendar-sync-token');
    expect(restored.lastSuccessfulSync, lastSync);
    expect(json.keys, isNot(contains('accessToken')));
    expect(json.keys, isNot(contains('refreshToken')));
  });

  test('disconnect clears identity and sync state but keeps preferences', () {
    const settings = GoogleCalendarUserSettings(
      syncEnabled: true,
      googleAccountEmail: 'dentist@gmail.com',
      credentialReference: 'secure:apexo-user-1',
      calendarId: 'dedicated-calendar',
      direction: GoogleCalendarSyncDirection.apexoToGoogle,
      appointmentScope: GoogleCalendarAppointmentScope.assignedToMe,
      titleMode: GoogleCalendarTitleMode.patientName,
      includePhone: false,
      includeAddress: true,
      syncToken: 'sync-token',
      lastError: 'error',
    );

    final disconnected = settings.disconnected();

    expect(disconnected.isConnected, isFalse);
    expect(disconnected.syncEnabled, isFalse);
    expect(disconnected.googleAccountEmail, isEmpty);
    expect(disconnected.credentialReference, isEmpty);
    expect(disconnected.syncToken, isEmpty);
    expect(disconnected.lastError, isEmpty);
    expect(disconnected.calendarId, 'dedicated-calendar');
    expect(disconnected.direction, GoogleCalendarSyncDirection.apexoToGoogle);
    expect(
      disconnected.appointmentScope,
      GoogleCalendarAppointmentScope.assignedToMe,
    );
    expect(disconnected.titleMode, GoogleCalendarTitleMode.patientName);
    expect(disconnected.includePhone, isFalse);
    expect(disconnected.includeAddress, isTrue);
  });

  test('legacy settings default to automatic appointment scope', () {
    final restored = GoogleCalendarUserSettings.fromJson(const {});

    expect(
      restored.appointmentScope,
      GoogleCalendarAppointmentScope.automatic,
    );
  });
}
