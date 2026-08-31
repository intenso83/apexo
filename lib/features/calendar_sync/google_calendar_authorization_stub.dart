import 'google_calendar_authorization_models.dart';

class GoogleCalendarAuthorizationImpl implements GoogleCalendarAuthorization {
  @override
  bool get isSupported => false;

  @override
  Future<GoogleCalendarAuthorizationSession> authorize({
    required String clientId,
    required String apexoAccountId,
    required bool forceAccountChooser,
  }) {
    throw const GoogleCalendarAuthorizationException(
      'Google Calendar connection is currently available in Apexo Web.',
    );
  }

  @override
  Future<void> revoke(GoogleCalendarAuthorizationSession session) async {}
}
