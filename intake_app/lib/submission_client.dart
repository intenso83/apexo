import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    required Uint8List pdfBytes,
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
    if (pdfBytes.isEmpty || pdfBytes.length > 2 * 1024 * 1024) {
      throw const IntakeSubmissionException(
        'The signed PDF could not be prepared safely.',
      );
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
      final boundary =
          'apexo-intake-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _writeTextPart(request, boundary, 'session_id', sessionId.trim());
      _writeTextPart(request, boundary, 'packet', jsonEncode(packet));
      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="intake_pdf"; '
        'filename="signed-patient-intake.pdf"\r\n',
      );
      request.write('Content-Type: application/pdf\r\n\r\n');
      request.add(pdfBytes);
      request.write('\r\n--$boundary--\r\n');
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

  void _writeTextPart(
    HttpClientRequest request,
    String boundary,
    String name,
    String value,
  ) {
    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="$name"\r\n');
    request.write('Content-Type: text/plain; charset=utf-8\r\n\r\n');
    request.add(utf8.encode(value));
    request.write('\r\n');
  }
}
