class GoogleCalendarAuthorizationSession {
  final String accessToken;
  final String email;
  final DateTime expiresAt;
  final String grantedScopes;

  const GoogleCalendarAuthorizationSession({
    required this.accessToken,
    required this.email,
    required this.expiresAt,
    this.grantedScopes = '',
  });

  bool get isValid =>
      accessToken.isNotEmpty &&
      DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 1)));
}

abstract class GoogleCalendarAuthorization {
  bool get isSupported;

  Future<GoogleCalendarAuthorizationSession> authorize({
    required String clientId,
    required String apexoAccountId,
    required bool forceAccountChooser,
  });

  Future<void> revoke(GoogleCalendarAuthorizationSession session);
}

class GoogleCalendarAuthorizationException implements Exception {
  final String message;

  const GoogleCalendarAuthorizationException(this.message);

  @override
  String toString() => message;
}
