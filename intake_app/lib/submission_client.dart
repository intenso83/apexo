import 'dart:async';
import 'dart:convert';
import 'dart:io';

const compiledIntakeServerUrl = String.fromEnvironment('INTAKE_SERVER_URL');

class IntakeSubmissionException implements Exception {
  const IntakeSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IntakeSubmissionClient {
  const IntakeSubmissionClient();

  bool get isConfigured => compiledIntakeServerUrl.trim().isNotEmpty;

  Future<void> submit({
    required String sessionId,
    required Map<String, dynamic> packet,
  }) async {
    final base = compiledIntakeServerUrl.trim();
    final uri = Uri.tryParse(base);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const IntakeSubmissionException(
        'The clinic submission service is not configured securely.',
      );
    }
    if (sessionId.trim().isEmpty) {
      throw const IntakeSubmissionException('The intake session is missing.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final endpoint = uri.replace(
        path:
            '${uri.path.replaceAll(RegExp(r'/$'), '')}/api/apexo/intake/submit',
      );
      final request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        jsonEncode({'session_id': sessionId.trim(), 'packet': packet}),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final responseText = await utf8.decoder
          .bind(response)
          .take(32)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message =
            'The form could not be submitted. Please call a member of staff.';
        try {
          final body = jsonDecode(responseText);
          if (body is Map && body['message'] is String) {
            message = body['message'] as String;
          }
        } catch (_) {
          // Do not expose raw server output on a patient-facing screen.
        }
        throw IntakeSubmissionException(message);
      }
    } on TimeoutException {
      throw const IntakeSubmissionException(
        'The clinic connection timed out. Please call a member of staff.',
      );
    } on SocketException {
      throw const IntakeSubmissionException(
        'The tablet is offline. Please call a member of staff.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
