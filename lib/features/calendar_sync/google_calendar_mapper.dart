import 'dart:convert';

import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:crypto/crypto.dart';

import 'google_calendar_models.dart';

class GoogleCalendarMapper {
  static const genericSummary = 'Dental appointment';

  String eventIdFor({
    required String clinicId,
    required String appointmentId,
  }) {
    final digest = sha256.convert(utf8.encode('$clinicId|$appointmentId'));
    // Google event IDs accept base32hex characters. A hexadecimal digest and
    // the a-p-e-c-a-l prefix remain inside that alphabet.
    return 'apecal${digest.toString().substring(0, 32)}';
  }

  String fingerprint(
    Appointment appointment, {
    required String summary,
  }) {
    final canonical = jsonEncode({
      'start': appointment.date.toUtc().toIso8601String(),
      'end': appointment.endDate.toUtc().toIso8601String(),
      'summary': summary,
      'archived': appointment.archived == true,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  GoogleCalendarEvent fromAppointment({
    required Appointment appointment,
    required GoogleCalendarSyncPreferences preferences,
    required String patientName,
  }) {
    final summary = preferences.titleMode == GoogleCalendarTitleMode.patientName
        ? _safePatientName(patientName)
        : genericSummary;
    return GoogleCalendarEvent(
      id: appointment.googleCalendarEventId.isNotEmpty
          ? appointment.googleCalendarEventId
          : eventIdFor(
              clinicId: preferences.clinicId,
              appointmentId: appointment.id,
            ),
      status: 'confirmed',
      summary: summary,
      description: 'Managed by Apexo.',
      start: appointment.date,
      end: appointment.endDate,
      privateProperties: {
        'apexoClinicId': preferences.clinicId,
        'apexoAppointmentId': appointment.id,
        'apexoManaged': '1',
      },
    );
  }

  bool applyRemoteTime(
    GoogleCalendarEvent event,
    Appointment appointment,
  ) {
    if (event.start == null || event.end == null) return false;
    final minutes = event.end!.difference(event.start!).inMinutes;
    if (minutes <= 0) return false;
    appointment.date = event.start!.toLocal();
    appointment.duration = minutes;
    return true;
  }

  void applyRemoteMetadata({
    required GoogleCalendarEvent event,
    required String calendarId,
    required String fingerprint,
    required Appointment appointment,
  }) {
    appointment.googleCalendarEventId = event.id;
    appointment.googleCalendarId = calendarId;
    appointment.googleCalendarEtag = event.etag;
    appointment.googleCalendarUpdatedAt = event.updatedAt;
    appointment.googleCalendarHtmlLink = event.htmlLink;
    appointment.googleCalendarSyncFingerprint = fingerprint;
  }

  String _safePatientName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? genericSummary : trimmed;
  }
}
