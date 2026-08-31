import 'dart:convert';
import 'dart:js_interop';

import 'google_calendar_authorization_models.dart';

@JS('apexoGoogleCalendarOAuthSupported')
external JSBoolean _oauthSupported();

@JS('apexoGoogleCalendarAuthorize')
external JSPromise<JSString> _authorize(
  JSString clientId,
  JSString apexoAccountId,
  JSBoolean forceAccountChooser,
);

@JS('apexoGoogleCalendarRevoke')
external JSPromise<JSString> _revoke(JSString accessToken);

class GoogleCalendarAuthorizationImpl implements GoogleCalendarAuthorization {
  @override
  bool get isSupported {
    try {
      return _oauthSupported().toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GoogleCalendarAuthorizationSession> authorize({
    required String clientId,
    required String apexoAccountId,
    required bool forceAccountChooser,
  }) async {
    if (clientId.trim().isEmpty) {
      throw const GoogleCalendarAuthorizationException(
        'A Google OAuth client ID is required.',
      );
    }
    try {
      final raw = (await _authorize(
        clientId.trim().toJS,
        apexoAccountId.toJS,
        forceAccountChooser.toJS,
      ).toDart)
          .toDart;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final token = json['accessToken']?.toString() ?? '';
      final email = json['email']?.toString() ?? '';
      final expiryMilliseconds =
          (json['expiresAtMilliseconds'] as num?)?.toInt() ?? 0;
      if (token.isEmpty || email.isEmpty || expiryMilliseconds <= 0) {
        throw const GoogleCalendarAuthorizationException(
          'Google returned an incomplete authorization response.',
        );
      }
      return GoogleCalendarAuthorizationSession(
        accessToken: token,
        email: email,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          expiryMilliseconds,
          isUtc: true,
        ),
        grantedScopes: json['scope']?.toString() ?? '',
      );
    } catch (error) {
      if (error is GoogleCalendarAuthorizationException) rethrow;
      throw GoogleCalendarAuthorizationException(
        _friendlyAuthorizationError(error.toString()),
      );
    }
  }

  @override
  Future<void> revoke(GoogleCalendarAuthorizationSession session) async {
    if (session.accessToken.isEmpty) return;
    try {
      await _revoke(session.accessToken.toJS).toDart;
    } catch (error) {
      throw GoogleCalendarAuthorizationException(
        _friendlyAuthorizationError(error.toString()),
      );
    }
  }

  String _friendlyAuthorizationError(String raw) {
    final normalized = raw
        .replaceFirst('JavaScriptError: ', '')
        .replaceFirst('Error: ', '')
        .trim();
    if (normalized.contains('popup_closed')) {
      return 'The Google account window was closed before authorization.';
    }
    if (normalized.contains('popup_failed_to_open')) {
      return 'The browser blocked the Google account window. Allow pop-ups and try again.';
    }
    if (normalized.contains('origin_mismatch')) {
      return 'This Apexo address is not listed as an authorized JavaScript origin in Google Cloud.';
    }
    return normalized.isEmpty ? 'Google authorization failed.' : normalized;
  }
}
