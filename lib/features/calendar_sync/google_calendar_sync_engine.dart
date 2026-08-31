import 'package:apexo/features/appointments/appointment_model.dart';

import 'google_calendar_gateway.dart';
import 'google_calendar_mapper.dart';
import 'google_calendar_models.dart';

typedef SaveSyncedAppointment = Future<void> Function(Appointment appointment);
typedef AppointmentPatientName = String Function(Appointment appointment);

/// Reconciles Apexo appointments with only the Google events carrying Apexo's
/// private ownership markers. It never imports arbitrary personal events.
class GoogleCalendarSyncEngine {
  final GoogleCalendarGateway gateway;
  final GoogleCalendarMapper mapper;
  final DateTime Function() now;

  GoogleCalendarSyncEngine({
    required this.gateway,
    GoogleCalendarMapper? mapper,
    DateTime Function()? now,
  })  : mapper = mapper ?? GoogleCalendarMapper(),
        now = now ?? DateTime.now;

  Future<GoogleCalendarSyncResult> sync({
    required List<Appointment> appointments,
    required GoogleCalendarSyncPreferences preferences,
    required GoogleCalendarSyncState state,
    required SaveSyncedAppointment saveAppointment,
    required AppointmentPatientName patientName,
  }) async {
    if (!preferences.enabled) return const GoogleCalendarSyncResult();
    var fullResync = state.syncToken == null || state.syncToken!.isEmpty;
    _RemoteListing listing;
    try {
      listing = await _loadRemote(
        preferences: preferences,
        syncToken: state.syncToken,
      );
    } on GoogleCalendarSyncTokenInvalid {
      // Google requires clients to discard an invalid incremental token and
      // rebuild their cache with a new full sync.
      fullResync = true;
      listing = await _loadRemote(preferences: preferences);
    }

    final appointmentsById = {
      for (final appointment in appointments) appointment.id: appointment,
    };
    final remoteByAppointmentId = <String, GoogleCalendarEvent>{};
    final issues = <GoogleCalendarSyncIssue>[];
    for (final event in listing.events) {
      // Incremental list requests cannot use an extended-property filter, so
      // Google may return unrelated calendar changes. Ignore them completely.
      if (event.privateProperties['apexoManaged'] != '1' ||
          event.privateProperties['apexoClinicId'] != preferences.clinicId) {
        continue;
      }
      final appointmentId = event.privateProperties['apexoAppointmentId'] ?? '';
      if (appointmentId.isEmpty ||
          !appointmentsById.containsKey(appointmentId)) {
        issues.add(GoogleCalendarSyncIssue(
          type: GoogleCalendarSyncIssueType.orphanedRemoteEvent,
          appointmentId: appointmentId,
          eventId: event.id,
          message: 'Managed Google event has no matching Apexo appointment.',
        ));
        continue;
      }
      remoteByAppointmentId[appointmentId] = event;
    }

    var created = 0;
    var updatedInGoogle = 0;
    var updatedInApexo = 0;
    var deletedFromGoogle = 0;
    final current = now();
    final rangeStart = current.subtract(Duration(days: preferences.pastDays));
    final rangeEnd = current.add(Duration(days: preferences.futureDays));

    for (final appointment in appointments) {
      final remote = remoteByAppointmentId[appointment.id];
      final desired = mapper.fromAppointment(
        appointment: appointment,
        preferences: preferences,
        patientName: patientName(appointment),
      );
      final localFingerprint = mapper.fingerprint(
        appointment,
        summary: desired.summary,
      );
      final hasSyncMetadata = appointment.googleCalendarEventId.isNotEmpty;
      final localChanged = hasSyncMetadata &&
          appointment.googleCalendarSyncFingerprint.isNotEmpty &&
          appointment.googleCalendarSyncFingerprint != localFingerprint;

      if (appointment.archived == true) {
        if (hasSyncMetadata) {
          await gateway.deleteEvent(
            calendarId: _calendarFor(appointment, preferences),
            eventId: appointment.googleCalendarEventId,
          );
          _clearMetadata(appointment);
          await saveAppointment(appointment);
          deletedFromGoogle++;
        }
        continue;
      }

      final inWindow = !appointment.date.isBefore(rangeStart) &&
          appointment.date.isBefore(rangeEnd);

      if (remote == null) {
        if (!hasSyncMetadata && inWindow) {
          final inserted = await gateway.insertEvent(
            calendarId: preferences.calendarId,
            event: desired,
          );
          mapper.applyRemoteMetadata(
            event: inserted,
            calendarId: preferences.calendarId,
            fingerprint: localFingerprint,
            appointment: appointment,
          );
          await saveAppointment(appointment);
          created++;
        } else if (hasSyncMetadata && localChanged) {
          final patched = await gateway.patchEvent(
            calendarId: _calendarFor(appointment, preferences),
            eventId: appointment.googleCalendarEventId,
            event: desired,
          );
          mapper.applyRemoteMetadata(
            event: patched,
            calendarId: _calendarFor(appointment, preferences),
            fingerprint: localFingerprint,
            appointment: appointment,
          );
          await saveAppointment(appointment);
          updatedInGoogle++;
        }
        continue;
      }

      if (remote.isCancelled) {
        issues.add(GoogleCalendarSyncIssue(
          type: GoogleCalendarSyncIssueType.remoteDeletion,
          appointmentId: appointment.id,
          eventId: remote.id,
          message: 'Google event was deleted; Apexo kept the appointment.',
        ));
        continue;
      }

      if (!hasSyncMetadata) {
        if (!_remoteMatchesAppointment(remote, appointment)) {
          issues.add(GoogleCalendarSyncIssue(
            type: GoogleCalendarSyncIssueType.conflict,
            appointmentId: appointment.id,
            eventId: remote.id,
            message:
                'Existing Apexo-managed event differs from the appointment.',
          ));
          continue;
        }
        mapper.applyRemoteMetadata(
          event: remote,
          calendarId: preferences.calendarId,
          fingerprint: localFingerprint,
          appointment: appointment,
        );
        await saveAppointment(appointment);
        continue;
      }

      final remoteChanged = appointment.googleCalendarEtag.isNotEmpty &&
          remote.etag.isNotEmpty &&
          appointment.googleCalendarEtag != remote.etag;
      if (localChanged && remoteChanged) {
        issues.add(GoogleCalendarSyncIssue(
          type: GoogleCalendarSyncIssueType.conflict,
          appointmentId: appointment.id,
          eventId: remote.id,
          message: 'Appointment changed in both Apexo and Google Calendar.',
        ));
        continue;
      }

      if (remoteChanged &&
          preferences.direction == GoogleCalendarSyncDirection.twoWay) {
        if (!mapper.applyRemoteTime(remote, appointment)) {
          issues.add(GoogleCalendarSyncIssue(
            type: GoogleCalendarSyncIssueType.invalidRemoteTime,
            appointmentId: appointment.id,
            eventId: remote.id,
            message: 'Google event has no valid start/end duration.',
          ));
          continue;
        }
        final pulledFingerprint = mapper.fingerprint(
          appointment,
          summary: desired.summary,
        );
        mapper.applyRemoteMetadata(
          event: remote,
          calendarId: preferences.calendarId,
          fingerprint: pulledFingerprint,
          appointment: appointment,
        );
        await saveAppointment(appointment);
        updatedInApexo++;
        continue;
      }

      if (localChanged || remoteChanged) {
        final patched = await gateway.patchEvent(
          calendarId: _calendarFor(appointment, preferences),
          eventId: appointment.googleCalendarEventId,
          event: desired,
        );
        mapper.applyRemoteMetadata(
          event: patched,
          calendarId: _calendarFor(appointment, preferences),
          fingerprint: localFingerprint,
          appointment: appointment,
        );
        await saveAppointment(appointment);
        updatedInGoogle++;
      }
    }

    return GoogleCalendarSyncResult(
      created: created,
      updatedInGoogle: updatedInGoogle,
      updatedInApexo: updatedInApexo,
      deletedFromGoogle: deletedFromGoogle,
      performedFullResync: fullResync,
      nextSyncToken: listing.nextSyncToken,
      issues: issues,
    );
  }

  Future<_RemoteListing> _loadRemote({
    required GoogleCalendarSyncPreferences preferences,
    String? syncToken,
  }) async {
    final events = <GoogleCalendarEvent>[];
    String? pageToken;
    String? nextSyncToken;
    final current = now();
    do {
      final page = await gateway.listEvents(
        calendarId: preferences.calendarId,
        clinicId: preferences.clinicId,
        syncToken: syncToken,
        pageToken: pageToken,
        timeMin: syncToken == null
            ? current.subtract(Duration(days: preferences.pastDays))
            : null,
        timeMax: syncToken == null
            ? current.add(Duration(days: preferences.futureDays))
            : null,
      );
      events.addAll(page.events);
      pageToken = page.nextPageToken;
      if (pageToken == null) nextSyncToken = page.nextSyncToken;
    } while (pageToken != null);
    return _RemoteListing(events, nextSyncToken);
  }

  bool _remoteMatchesAppointment(
    GoogleCalendarEvent remote,
    Appointment appointment,
  ) {
    if (remote.start == null || remote.end == null) return false;
    return remote.start!.toUtc() == appointment.date.toUtc() &&
        remote.end!.toUtc() == appointment.endDate.toUtc();
  }

  String _calendarFor(
    Appointment appointment,
    GoogleCalendarSyncPreferences preferences,
  ) =>
      appointment.googleCalendarId.isEmpty
          ? preferences.calendarId
          : appointment.googleCalendarId;

  void _clearMetadata(Appointment appointment) {
    appointment.googleCalendarEventId = '';
    appointment.googleCalendarId = '';
    appointment.googleCalendarEtag = '';
    appointment.googleCalendarUpdatedAt = null;
    appointment.googleCalendarHtmlLink = '';
    appointment.googleCalendarSyncFingerprint = '';
  }
}

class _RemoteListing {
  final List<GoogleCalendarEvent> events;
  final String? nextSyncToken;

  const _RemoteListing(this.events, this.nextSyncToken);
}
