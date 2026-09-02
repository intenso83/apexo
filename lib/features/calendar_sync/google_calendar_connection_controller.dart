import 'dart:async';

import 'package:apexo/core/observable.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/utils/hash.dart';
import 'package:http/http.dart' as http;

import 'google_calendar_authorization.dart';
import 'google_calendar_gateway.dart';
import 'google_calendar_contact_notes.dart';
import 'google_calendar_models.dart';
import 'google_calendar_sync_engine.dart';

enum GoogleCalendarConnectionPhase {
  idle,
  authorizing,
  syncing,
  connected,
  error,
}

class GoogleCalendarRuntimeState {
  final String accountId;
  final GoogleCalendarConnectionPhase phase;
  final String message;
  final GoogleCalendarSyncResult? lastResult;

  const GoogleCalendarRuntimeState({
    this.accountId = '',
    this.phase = GoogleCalendarConnectionPhase.idle,
    this.message = '',
    this.lastResult,
  });

  bool get isBusy =>
      phase == GoogleCalendarConnectionPhase.authorizing ||
      phase == GoogleCalendarConnectionPhase.syncing;
}

/// Owns only short-lived, in-memory Google access tokens. Persistent settings
/// contain the connected email and sync cursor, never an OAuth token.
class GoogleCalendarConnectionController {
  final GoogleCalendarAuthorization authorization;
  final http.Client httpClient;
  final Map<String, GoogleCalendarAuthorizationSession> _sessions = {};
  final Map<String, List<GoogleCalendarBusyBlock>> _busyBlocks = {};
  Timer? _automaticSyncTimer;
  bool _watchingAppointments = false;

  GoogleCalendarConnectionController({
    GoogleCalendarAuthorization? authorization,
    http.Client? httpClient,
  })  : authorization = authorization ?? googleCalendarAuthorization,
        httpClient = httpClient ?? http.Client();

  final state = ObservableState(const GoogleCalendarRuntimeState());

  List<GoogleCalendarBusyBlock> busyBlocksFor(String accountId) =>
      List.unmodifiable(_busyBlocks[accountId] ?? const []);

  bool hasActiveSession(String accountId) =>
      _sessions[accountId]?.isValid == true;

  /// Refreshes Google changes when the calendar is opened, but only when a
  /// valid in-memory session already exists. It never opens a sign-in popup.
  Future<void> syncIfActive({
    Duration minimumInterval = const Duration(seconds: 15),
  }) async {
    final accountId = login.currentAccountID.isNotEmpty
        ? login.currentAccountID
        : login.email;
    if (accountId.isEmpty || state().isBusy || !hasActiveSession(accountId)) {
      return;
    }
    final settings = localSettings.googleCalendarForUser(accountId);
    final lastSync = settings.lastSuccessfulSync;
    if (!settings.syncEnabled ||
        settings.autoSyncDelaySeconds <= 0 ||
        !globalSettings.googleCalendarSyncEnabled ||
        globalSettings.googleCalendarClientId.trim().isEmpty ||
        (lastSync != null &&
            DateTime.now().toUtc().difference(lastSync) < minimumInterval)) {
      return;
    }
    await syncNow(
      accountId: accountId,
      clientId: globalSettings.googleCalendarClientId,
    );
  }

  /// Watches saved appointment changes and batches a burst of edits into one
  /// Google request after the user's configured quiet period. This is not a
  /// polling loop and never opens an OAuth window automatically.
  void startWatchingAppointments() {
    if (_watchingAppointments) return;
    _watchingAppointments = true;
    appointments.observableMap.observe(_scheduleAutomaticSync);
  }

  void _scheduleAutomaticSync(List<DictEvent> events) {
    final hasAppointmentChange = events.any((event) =>
        event.id != '__ignore_view__' &&
        event.id != '__removed_all__' &&
        event.document is Appointment);
    if (!hasAppointmentChange || state().isBusy) return;

    final accountId = login.currentAccountID.isNotEmpty
        ? login.currentAccountID
        : login.email;
    final settings = localSettings.googleCalendarForUser(accountId);
    final delay = settings.autoSyncDelaySeconds;
    final configured = globalSettings.googleCalendarSyncEnabled &&
        globalSettings.googleCalendarClientId.trim().isNotEmpty;
    if (accountId.isEmpty ||
        delay <= 0 ||
        !configured ||
        !settings.syncEnabled ||
        !hasActiveSession(accountId)) {
      return;
    }

    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = Timer(Duration(seconds: delay), () async {
      final latest = localSettings.googleCalendarForUser(accountId);
      if (state().isBusy ||
          latest.autoSyncDelaySeconds <= 0 ||
          !latest.syncEnabled ||
          !hasActiveSession(accountId)) {
        return;
      }
      await syncNow(
        accountId: accountId,
        clientId: globalSettings.googleCalendarClientId,
        refreshBusyBlocks: false,
      );
    });
  }

  int assignedAppointmentCount(String accountId) =>
      assignedAppointments(appointments.present.values, accountId).length;

  bool syncsAllAppointments(String accountId) {
    final scope =
        localSettings.googleCalendarForUser(accountId).appointmentScope;
    return scope == GoogleCalendarAppointmentScope.allAppointments ||
        (scope == GoogleCalendarAppointmentScope.automatic && login.isAdmin);
  }

  int syncAppointmentCount(String accountId) => appointmentsForSync(
        appointments.present.values,
        accountId,
        scope: localSettings.googleCalendarForUser(accountId).appointmentScope,
        isAdmin: login.isAdmin,
      ).length;

  static List<Appointment> assignedAppointments(
    Iterable<Appointment> source,
    String accountId,
  ) =>
      source
          .where((appointment) =>
              accountId.isNotEmpty &&
              appointment.operatorsIDs.contains(accountId))
          .toList(growable: false);

  static List<Appointment> appointmentsForSync(
    Iterable<Appointment> source,
    String accountId, {
    required GoogleCalendarAppointmentScope scope,
    required bool isAdmin,
  }) {
    final syncAll = scope == GoogleCalendarAppointmentScope.allAppointments ||
        (scope == GoogleCalendarAppointmentScope.automatic && isAdmin);
    if (syncAll) return source.toList(growable: false);
    return assignedAppointments(source, accountId);
  }

  Future<void> connect({
    required String accountId,
    required String clientId,
  }) async {
    if (!_validateConfiguration(accountId, clientId)) return;
    state(GoogleCalendarRuntimeState(
      accountId: accountId,
      phase: GoogleCalendarConnectionPhase.authorizing,
      message: 'Opening the Google account chooser…',
    ));
    try {
      final session = await authorization.authorize(
        clientId: clientId,
        apexoAccountId: accountId,
        forceAccountChooser: true,
      );
      final previous = localSettings.googleCalendarForUser(accountId);
      if (previous.googleAccountEmail.isNotEmpty &&
          previous.googleAccountEmail.toLowerCase() !=
              session.email.toLowerCase()) {
        throw GoogleCalendarAuthorizationException(
          'This Apexo user is already linked to '
          '${previous.googleAccountEmail}. Disconnect first to change accounts.',
        );
      }
      _sessions[accountId] = session;
      localSettings.setGoogleCalendarForUser(
        accountId,
        previous.copyWith(
          syncEnabled: true,
          googleAccountEmail: session.email,
          credentialReference: 'gis:$accountId',
          syncToken: previous.syncToken,
          lastError: '',
        ),
      );
      state(GoogleCalendarRuntimeState(
        accountId: accountId,
        phase: GoogleCalendarConnectionPhase.connected,
        message: 'Connected to ${session.email}.',
      ));
    } catch (error) {
      _setError(accountId, error);
    }
  }

  Future<void> disconnect(String accountId) async {
    _automaticSyncTimer?.cancel();
    final session = _sessions.remove(accountId);
    try {
      if (session != null) await authorization.revoke(session);
    } catch (_) {
      // Local disconnect must still succeed if Google cannot be reached.
    }
    localSettings.disconnectGoogleCalendarForUser(accountId);
    _busyBlocks.remove(accountId);
    state(GoogleCalendarRuntimeState(
      accountId: accountId,
      phase: GoogleCalendarConnectionPhase.idle,
      message: 'Google Calendar disconnected from this Apexo user.',
    ));
  }

  Future<void> syncNow({
    required String accountId,
    required String clientId,
    bool refreshBusyBlocks = true,
  }) async {
    if (!_validateConfiguration(accountId, clientId)) return;
    final settings = localSettings.googleCalendarForUser(accountId);
    if (!settings.syncEnabled) {
      return _setError(
        accountId,
        const GoogleCalendarAuthorizationException(
          'Enable synchronization for this Apexo user first.',
        ),
      );
    }
    try {
      var session = _sessions[accountId];
      if (session?.isValid != true) {
        state(GoogleCalendarRuntimeState(
          accountId: accountId,
          phase: GoogleCalendarConnectionPhase.authorizing,
          message: 'Renewing Google authorization…',
        ));
        session = await authorization.authorize(
          clientId: clientId,
          apexoAccountId: accountId,
          forceAccountChooser: settings.googleAccountEmail.isEmpty,
        );
        if (settings.googleAccountEmail.isNotEmpty &&
            settings.googleAccountEmail.toLowerCase() !=
                session.email.toLowerCase()) {
          throw GoogleCalendarAuthorizationException(
            'Google returned ${session.email}, but this Apexo user is linked '
            'to ${settings.googleAccountEmail}. Disconnect first to change accounts.',
          );
        }
        _sessions[accountId] = session;
      }

      state(GoogleCalendarRuntimeState(
        accountId: accountId,
        phase: GoogleCalendarConnectionPhase.syncing,
        message: 'Synchronizing appointments…',
      ));
      final gateway = GoogleCalendarHttpGateway(
        client: httpClient,
        accessTokenProvider: () async {
          final current = _sessions[accountId];
          if (current?.isValid != true) {
            throw const GoogleCalendarAuthorizationException(
              'Google authorization expired. Press Sync now again.',
            );
          }
          return current!.accessToken;
        },
      );
      final eligible = appointmentsForSync(
        appointments.docs.values,
        accountId,
        scope: settings.appointmentScope,
        isAdmin: login.isAdmin,
      );
      final eligibleIds = eligible.map((appointment) => appointment.id).toSet();
      final removedAssignments = appointments.docs.values
          .where((appointment) =>
              !eligibleIds.contains(appointment.id) &&
              appointment.googleCalendarLinkFor(accountId).isLinked)
          .toList(growable: false);
      var removedFromGoogle = 0;
      for (final appointment in removedAssignments) {
        final link = appointment.googleCalendarLinkFor(accountId);
        await gateway.deleteEvent(
          calendarId:
              link.calendarId.isEmpty ? settings.calendarId : link.calendarId,
          eventId: link.eventId,
        );
        appointment.removeGoogleCalendarLink(accountId);
        appointments.set(appointment);
        removedFromGoogle++;
      }
      final engineResult =
          await GoogleCalendarSyncEngine(gateway: gateway).sync(
        appointments: eligible,
        preferences: GoogleCalendarSyncPreferences(
          enabled: true,
          calendarId: settings.calendarId,
          clinicId: simpleHash(login.url),
          accountId: accountId,
          direction: settings.direction,
          titleMode: settings.titleMode,
          includePhone: settings.includePhone,
          includeMobile: settings.includeMobile,
          includeEmail: settings.includeEmail,
          includeAddress: settings.includeAddress,
        ),
        state: GoogleCalendarSyncState(
          syncToken: settings.syncToken,
          lastSuccessfulSync: settings.lastSuccessfulSync,
        ),
        saveAppointment: (appointment) async {
          appointments.set(appointment);
        },
        patientName: (appointment) =>
            appointment.patient?.prototypeDisplayName ?? appointment.title,
        description: (appointment, preferences) =>
            GoogleCalendarContactNotes().forPatient(
          appointment.patient,
          preferences,
          patientUrl: _patientUrl(appointment.patientID),
          openPatientLabel: txt('googleCalendarOpenPatient'),
        ),
      );
      final googleBusyBlocks = settings.showGoogleBusyBlocks
          ? refreshBusyBlocks
              ? await _loadBusyBlocks(
                  gateway: gateway,
                  calendarId: settings.calendarId,
                  clinicId: simpleHash(login.url),
                )
              : _busyBlocks[accountId] ?? const <GoogleCalendarBusyBlock>[]
          : const <GoogleCalendarBusyBlock>[];
      _busyBlocks[accountId] = googleBusyBlocks;
      final result = GoogleCalendarSyncResult(
        created: engineResult.created,
        updatedInGoogle: engineResult.updatedInGoogle,
        updatedInApexo: engineResult.updatedInApexo,
        deletedFromGoogle: engineResult.deletedFromGoogle + removedFromGoogle,
        performedFullResync: engineResult.performedFullResync,
        nextSyncToken: engineResult.nextSyncToken,
        issues: engineResult.issues,
      );
      await appointments.waitUntilChangesAreProcessed();
      final issueMessage = result.issues.isEmpty
          ? ''
          : '${result.issues.length} item(s) need review.';
      localSettings.setGoogleCalendarForUser(
        accountId,
        localSettings.googleCalendarForUser(accountId).copyWith(
              googleAccountEmail: session!.email,
              credentialReference: 'gis:$accountId',
              syncToken: result.nextSyncToken ?? '',
              lastSuccessfulSync: DateTime.now().toUtc(),
              lastError: issueMessage,
            ),
      );
      state(GoogleCalendarRuntimeState(
        accountId: accountId,
        phase: GoogleCalendarConnectionPhase.connected,
        message: _resultMessage(
          result,
          eligible.length,
          googleBusyBlocks.length,
        ),
        lastResult: result,
      ));
    } catch (error) {
      _setError(accountId, error);
    }
  }

  Future<List<GoogleCalendarBusyBlock>> _loadBusyBlocks({
    required GoogleCalendarGateway gateway,
    required String calendarId,
    required String clinicId,
  }) async {
    final events = <GoogleCalendarEvent>[];
    String? pageToken;
    final current = DateTime.now();
    do {
      final page = await gateway.listEvents(
        calendarId: calendarId,
        clinicId: clinicId,
        managedOnly: false,
        pageToken: pageToken,
        timeMin: current.subtract(const Duration(days: 90)),
        timeMax: current.add(const Duration(days: 365)),
      );
      events.addAll(page.events);
      pageToken = page.nextPageToken;
    } while (pageToken != null);

    return busyBlocksFromEvents(events);
  }

  static List<GoogleCalendarBusyBlock> busyBlocksFromEvents(
    Iterable<GoogleCalendarEvent> events,
  ) {
    return events
        .where((event) =>
            !event.isCancelled &&
            event.transparency != 'transparent' &&
            event.privateProperties['apexoManaged'] != '1' &&
            event.start != null &&
            event.end != null &&
            event.end!.isAfter(event.start!))
        .map((event) => GoogleCalendarBusyBlock(
              id: event.id,
              title: event.summary.trim().isEmpty
                  ? txt('googleCalendarBusyBlock')
                  : event.summary.trim(),
              start: event.start!.toLocal(),
              end: event.end!.toLocal(),
              htmlLink: event.htmlLink,
            ))
        .toList(growable: false);
  }

  String _patientUrl(String? patientId) {
    if (patientId == null || patientId.isEmpty) return '';
    return Uri.base.replace(
      queryParameters: {'openPatient': patientId},
      fragment: '',
    ).toString();
  }

  bool _validateConfiguration(String accountId, String clientId) {
    if (accountId.isEmpty) {
      _setError(
        accountId,
        const GoogleCalendarAuthorizationException(
          'A signed-in Apexo user is required.',
        ),
      );
      return false;
    }
    if (!globalSettings.googleCalendarSyncEnabled) {
      _setError(
        accountId,
        const GoogleCalendarAuthorizationException(
          'Enable the clinic Google Calendar integration first.',
        ),
      );
      return false;
    }
    if (clientId.trim().isEmpty) {
      _setError(
        accountId,
        const GoogleCalendarAuthorizationException(
          'Enter and save the public Google OAuth client ID first.',
        ),
      );
      return false;
    }
    if (!authorization.isSupported) {
      _setError(
        accountId,
        const GoogleCalendarAuthorizationException(
          'Google Calendar connection is currently available in Apexo Web.',
        ),
      );
      return false;
    }
    return true;
  }

  void _setError(String accountId, Object error) {
    final message = error.toString();
    final existing = localSettings.googleCalendarForUser(accountId);
    if (accountId.isNotEmpty) {
      localSettings.setGoogleCalendarForUser(
        accountId,
        existing.copyWith(lastError: message),
      );
    }
    state(GoogleCalendarRuntimeState(
      accountId: accountId,
      phase: GoogleCalendarConnectionPhase.error,
      message: message,
    ));
  }

  String _resultMessage(
    GoogleCalendarSyncResult result,
    int eligibleCount,
    int busyBlockCount,
  ) {
    final changed = result.created +
        result.updatedInGoogle +
        result.updatedInApexo +
        result.deletedFromGoogle;
    return 'Checked $eligibleCount synchronized appointment(s); '
        '$changed change(s), ${result.issues.length} item(s) to review; '
        '$busyBlockCount Google busy block(s).';
  }
}

final googleCalendarConnectionController = GoogleCalendarConnectionController()
  ..startWatchingAppointments();
